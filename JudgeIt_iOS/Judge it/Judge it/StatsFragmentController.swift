//
//  StatsFragmentController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 06/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

// TODO: special API endpoint for question stats may be useful.
// This is quite some quirky stuff in here at the moment.

import Foundation
import TTTAttributedLabel
import Charts
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


class StatsFragmentController : UIViewController, UITableViewDataSource, QuestionFragment, TTTAttributedLabelDelegate {
    
    @IBOutlet var backgroundImage: UIImageView!
    
    var question: Question?
    var choices: [Choice] = []
    var votedChoices: [Choice] = []
    var participants: [User] = []
    var ratingsForChoice: [Choice: [Rating]] = [:]
    var participantForRating: [Rating : User] = [:]
    
    var participantsWhoLeft = Set<User>()
    
    @IBOutlet var scrollView: UIScrollView!
    
    @IBOutlet var titleLabel: UILabel!
    
    @IBOutlet var pieChartTable: UITableView!
    @IBOutlet var pieChartHeight: NSLayoutConstraint!
    var pieChartCellHeight = (count: 0, cumulative: CGFloat(0))
    
    @IBOutlet var statsTable: UITableView!
    @IBOutlet var statsTableHeight: NSLayoutConstraint!
    var statsTableDataSource:StatsTableDataSource?
    
    @IBOutlet var participantsLabel: UILabel!
    @IBOutlet var participantsTable: UITableView!
    @IBOutlet var participantsHeight: NSLayoutConstraint!
    var participantsDatasource:ParticipantsDataSource?
    
    @IBOutlet weak var detailsHeader: UIView!
    @IBOutlet weak var participantsHeader: UIView!
    @IBOutlet weak var participantsFooter: UILabel!
    
    var cancelableBlockReload: dispatch_cancelable_block_t?
    
    var participantsCount = 0
    var moreThan50Participants = false
    
    func newData(){
        self.findOnce = false
        reload(force: true)
    }
    
    func reload(force:Bool = false) {
        if let question = self.question, self.view != nil {
            // enforced views being present
            let reloadQueue = DispatchQueue.global(priority: .default)
            reloadQueue.async(execute: {
                Choice.fetchChoices(question: question, choiceId: nil, alsoCached: !force, callbackOnce: true) { (choices, error) in
                    if let choices = choices {
                        Question.fetchUserCount(questionId: question.id, completion: {count, error in
                            if let count = count {
                                self.participantsCount = count
                                self.moreThan50Participants = count > 50
                                
                                if !question.isPublic && !self.moreThan50Participants {
                                    self.participantForRating.removeAll()
                                    User.fetchUsers(questionId: question.id, userId: nil, alsoCached: !force, queue: reloadQueue) { (users, error) in
                                        self.participants = users ?? []
                                        self.ratingsForChoice.removeAll()
                                        
                                        for user in self.participantsWhoLeft{
                                            if(!self.participants.contains(user)){
                                                self.participants.append(user)
                                            }
                                        }
                                        
                                        self.reloadRatings(question: question, choices: choices)
                                    }
                                } else {
                                    self.reloadRatings(question: question, choices: choices)
                                }
                            }
                        })
                    }
                }
            })
        }
    }
    
    func reloadRatings(question: Question, choices: [Choice]){
        let choice_dispatchGroup = DispatchGroup()
        for choice in choices {
            choice_dispatchGroup.enter()
            let ratingQueue = DispatchQueue.global(priority: .default)
            Rating.ratings(questionId: question.id, choiceId: choice.id, raterId: nil, callbackOnce: true, completion: { (ratings, error) in
                ratingQueue.async {
                    if let ratings = ratings {
                        DispatchQueue.main.async {
                            self.synced(lock: self.ratingsForChoice as AnyObject){
                                self.ratingsForChoice[choice] = ratings
                            }
                        }
                        
                        if !question.isPublic && !self.moreThan50Participants {
                            for rating in ratings {
                                for participant in self.participants {
                                    if participant.user_id == rating.raterId.rawId() {
                                        DispatchQueue.main.async {
                                            self.synced(lock: self.participantForRating as AnyObject) {
                                                self.participantForRating.updateValue(participant, forKey: rating)
                                            }
                                        }
                                        break
                                    }
                                }
                            }
                        }
                        
                    }
                    
                    choice_dispatchGroup.leave()
                }
            })
        }
        
        if self.participants.count > 0 && !self.findOnce {
            DispatchQueue.global(qos: .default).async {
                self.findLeftVoters()
            }
        }
        
        choice_dispatchGroup.notify(queue: DispatchQueue.main, execute: {
            // legacy height calc:
            self.participantsHeight.constant = self.moreThan50Participants ? 32 : 48 * CGFloat(self.participants.count)
            //                                    self.participantsHeight.constant = 400
            
            self.participantsDatasource = ParticipantsDataSource(questionId: question.id, choices: choices, participants: self.participants, ratingsForChoice: self.ratingsForChoice, parent: self)
            self.participantsTable.dataSource = self.participantsDatasource
            
            self.titleLabel.text = question.text
            
            self.choices = choices
            self.votedChoices = choices.filter({self.ratingsForChoice[$0]?.count > 0})
            self.pieChartTable.dataSource = self
            
            self.statsTableDataSource = StatsTableDataSource(questionId: question.id, participants: self.participants, choices: choices, ratingsForChoice: self.ratingsForChoice, participantForRating: self.participantForRating, parent: self)
            self.statsTable.dataSource = self.statsTableDataSource
            
            cancel_block(self.cancelableBlockReload)
            self.cancelableBlockReload = dispatch_after_delay(1.5) {
                self.participantsTable.reloadData()
                self.pieChartTable.reloadData()
                self.statsTable.reloadData()
            }
        })
    }
    
    func passQuestion(_ question: Question) {
        self.question = question
        
        self.makeRatingsSeen()
        
        reload()
    }
    
    var findOnce = false
    func findLeftVoters(){
        findOnce = true
        
        let findVoter_dispatchGroup = DispatchGroup()
        
        let participantIds = self.participants.map({$0.id()})
        
        findVoter_dispatchGroup.enter()
        Comment.fetchComments(questionId: question!.id, commentId: nil, callbackOnce: true, completion: {comments, error in
            let temp = comments?.flatMap({!participantIds.contains($0.userId) ? $0.userId : nil})
            
            if let temp = temp, Set(temp).count > 0{
                let unknownUsers = Set(temp)
                
                for user in unknownUsers{
                    findVoter_dispatchGroup.enter()
                    User.fetchUsers(questionId: self.question!.id, userId: user, callbackOnce: true, completion: {users, error in
                        if let user = users?.first{
                            self.participantsWhoLeft.insert(user)
                        }
                        findVoter_dispatchGroup.leave()
                    })
                }
            }
            findVoter_dispatchGroup.leave()
        })
        
        findVoter_dispatchGroup.enter()
        Choice.fetchChoices(question: question!, choiceId: nil, callbackOnce: true, queue: DispatchQueue.global(qos: .default)) { (choices, error) in
            if let choices = choices {
                for choice in choices {
                    
                    findVoter_dispatchGroup.enter()
                    Rating.ratings(questionId: self.question!.id, choiceId: choice.id, raterId: nil, callbackOnce: true, completion: { (ratings, error) in
                        if let ratings = ratings {
                            let unknownUsers = Set(ratings.flatMap({!participantIds.contains($0.raterId) ? $0.raterId : nil}))
                            
                            for user in unknownUsers{
                                findVoter_dispatchGroup.enter()
                                User.fetchUsers(questionId: self.question!.id, userId: user, callbackOnce: true, completion: {users, error in
                                    if let user = users?.first{
                                        self.participantsWhoLeft.insert(user)
                                    }
                                    findVoter_dispatchGroup.leave()
                                })
                            }
                        }
                        
                        findVoter_dispatchGroup.leave()
                    })
                }
            }
            findVoter_dispatchGroup.leave()
        }
        
        findVoter_dispatchGroup.notify(queue: DispatchQueue.main, execute: {
            if self.participantsWhoLeft.count > 0 {
                self.findOnce = true
                self.reload()
            }
        })
        
    }
    
    deinit {
        statsTable.removeObserver(self, forKeyPath: "contentSize")
        pieChartTable.removeObserver(self, forKeyPath: "contentSize")
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        statsTable.estimatedRowHeight = 30
        statsTable.rowHeight = UITableViewAutomaticDimension
        
        pieChartTable.estimatedRowHeight = 64
        pieChartTable.rowHeight = UITableViewAutomaticDimension
        
        self.automaticallyAdjustsScrollViewInsets = false
        
        statsTable.addObserver(self, forKeyPath: "contentSize", options: NSKeyValueObservingOptions([.new, .initial]), context: nil)
        
        pieChartTable.addObserver(self, forKeyPath: "contentSize", options: NSKeyValueObservingOptions([.new, .initial]), context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(newData), name: NSNotification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let prefs = UserDefaults.standard
        if let path = prefs.object(forKey: "wallpaper_path") as? String{
            if let dir : NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first as NSString?{
                let relativePath = dir.appendingPathComponent(path)
                backgroundImage.image = UIImage(contentsOfFile: relativePath)
            }
        } else if let color = prefs.colorForKey("wallpaper_color"){
            backgroundImage.backgroundColor = color
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tap(_:)))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
        
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        self.view.setNeedsDisplay()
        self.makeRatingsSeen()
        
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIScreenName, value: "Stats")
        tracker?.send((GAIDictionaryBuilder.createScreenView().build() as NSDictionary) as! [AnyHashable: Any])
    }
    
    func applicationDidBecomeActive() {
        self.makeRatingsSeen()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if(object as? AnyObject === statsTable){
            if moreThan50Participants || (self.question?.isPublic ?? false){
                self.detailsHeader.isHidden = true
                self.statsTableHeight.constant = 0
                self.participantsFooter.isHidden = true
                
                if self.question!.isPublic {
                    self.participantsHeight.constant = 0
                    self.participantsLabel.isHidden = true
                    self.participantsHeader.isHidden = true
                }
            } else{
                self.statsTableHeight.constant = self.statsTable.contentSize.height
            }
        } else if(object as? AnyObject === pieChartTable){
            self.pieChartHeight.constant = self.pieChartTable.contentSize.height
        }
    }
    
    func makeRatingsSeen() {
        if UIApplication.shared.applicationState != .active {
            return
        }
        
        if let parentViewController = self.parent as? UITabBarController {
            if parentViewController.selectedViewController == self {
                if let questionId = self.question?.id {
                    Question.makeRatingsSeen(questionId: questionId) { (madeSomeSeen, error) in
                        if error == nil && madeSomeSeen?.count > 0 {
                            if let parentViewController = self.parent as? UITabBarController {
                                parentViewController.tabBar.items![1].badgeValue = nil
                            }
                            
                            NotificationCenter.default.post(name: Notification.Name(rawValue: AppDelegate.NewDataDidBecomeAvailableNotification), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return self.votedChoices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = pieChartTable.dequeueReusableCell(withIdentifier: "pieChartCell")!
        
        if let choice = votedChoices[safe: indexPath.row]{
            let choiceLabel = cell.viewWithTag(100) as? TTTAttributedLabel
            
            choiceLabel?.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.link.rawValue
            choiceLabel?.linkAttributes = [kCTForegroundColorAttributeName as AnyHashable : UIColor.blue.cgColor,kCTUnderlineStyleAttributeName as AnyHashable : NSNumber(value: true as Bool)]
            choiceLabel?.activeLinkAttributes = [NSForegroundColorAttributeName : UIColor.purple]
            choiceLabel?.delegate = self
            
            let choiceIndex = self.choices.index(where: {$0.id == choice.id})
            choiceLabel?.text = choice.text.trim().length > 0 ? choice.text : "\(NSLocalizedString("choice_choice", comment: "")) \((choiceIndex ?? 0)+1)"
            
            if let ratings = self.ratingsForChoice[choice] {
                let pieChart = cell.viewWithTag(101) as? PieChartView
                pieChart?.noDataText = NSLocalizedString("choice_no_votes", comment: "No votes to display pie charts")
                
                var xLabels = [String]()
                var colors = [UIColor]()
                var dataEntries = [ChartDataEntry]()
                let contra = ratings.reduce(0, {(sum, rating) in
                    return sum + (rating.rating == -1 ? 1 : 0)
                })
                if(contra > 0){
                    dataEntries.append(ChartDataEntry(x: 0, y: Double(contra)))
                    xLabels.append("")
                    colors.append(UIColor.judgeItDownvoteColor)
                }
                
                let pro = ratings.reduce(0, {(sum, rating) in
                    return sum + (rating.rating == 1 ? 1 : 0)
                })
                if(pro > 0) {
                    dataEntries.append(ChartDataEntry(x: 1, y: Double(pro)))
                    xLabels.append("")
                    colors.append(UIColor.judgeItUpvoteColor)
                }
                let proPercentText = cell.viewWithTag(102) as! UILabel
                proPercentText.text = pro+contra > 0 ? "\(100*pro/(pro+contra))%" : "0%"
                
                let pieChartDataSet = PieChartDataSet(values: dataEntries, label: "")
                pieChartDataSet.colors = colors
                pieChartDataSet.drawValuesEnabled = false
                
                let pieChartData = PieChartData(dataSet: pieChartDataSet)
                pieChartData.highlightEnabled = false
                pieChart?.legend.enabled = false
                //            pieChart?.drawHoleEnabled = false
                pieChart?.holeColor = UIColor.clear
                //            pieChart?.holeAlpha = 0
                //            pieChart?.holeTransparent = true
                pieChart?.holeRadiusPercent = 0.7
                pieChart?.isUserInteractionEnabled = false
                pieChart?.data = pieChartData
                pieChart?.descriptionText = ""
                pieChart?.centerText =  ratings.count <= 999 ? "\(pro)-\(contra)" : "" // Don't show absolute vote count in large votings
                if(pieChart?.centerText?.length > 4){
                    pieChart?.centerText?.insert("\n", at: pieChart!.centerText!.index(after: pieChart!.centerText!.range(of: "-")!.lowerBound))
                }
            }
        }
        
        //            pieChart?.animate(xAxisDuration: 1.0, yAxisDuration: 1.0, easingOption: ChartEasingOption.EaseInCirc)
        
        
        pieChartCellHeight.cumulative += cell.bounds.height
        pieChartCellHeight.count += 1
        
        return cell
    }
    
    class StatsTableDataSource : NSObject, UITableViewDataSource {
        
        let questionId: String
        let choices: [Choice]
        let participants: [User]
        let ratingsForChoice: [Choice : [Rating]]
        let participantForRating: [Rating : User]
        
        var parent: StatsFragmentController
        
        var statsCellHeight = (count: 0, cumulative: CGFloat(0))
        
        init(questionId: String, participants: [User], choices: [Choice], ratingsForChoice: [Choice : [Rating]], participantForRating: [Rating : User], parent: StatsFragmentController) {
            self.questionId = questionId
            self.participants = participants
            self.choices = choices
            self.ratingsForChoice = ratingsForChoice
            self.participantForRating = participantForRating
            self.parent = parent
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return parent.moreThan50Participants || self.parent.question!.isPublic ? 0 : self.choices.count + 1
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "statsTableCell")!
            
            let choiceLabel = cell.viewWithTag(101) as! TTTAttributedLabel
            let proLabel = cell.viewWithTag(102) as! TTTAttributedLabel
            let contraLabel = cell.viewWithTag(103) as! TTTAttributedLabel
            let proPic = cell.viewWithTag(104) as! UIImageView
            let contraPic = cell.viewWithTag(105) as! UIImageView
            
            if(indexPath.row == 0){
                choiceLabel.text = " \(NSLocalizedString("choice_choice", comment: ""))"
                choiceLabel.textColor = UIColor.darkText
                choiceLabel.backgroundColor = UIColor(red: 0xEF, green: 0xEF, blue: 0xF4)
                
                proLabel.text = ""
                proLabel.textColor = UIColor.white
                proLabel.backgroundColor = UIColor(red: 0xEF, green: 0xEF, blue: 0xF4)
                
                contraLabel.text = ""
                contraLabel.textColor = UIColor.white
                contraLabel.backgroundColor = UIColor(red: 0xEF, green: 0xEF, blue: 0xF4)
                
                proPic.image = UIImage(imageLiteralResourceName: "choice_upvote")
                contraPic.image = UIImage(imageLiteralResourceName: "choice_downvote")
            } else{
                proPic.image = nil
                contraPic.image = nil
                
                if let choice = self.choices[safe: indexPath.row-1]{
                    
                    // Choice
                    choiceLabel.font = UIFont.systemFont(ofSize: 15)
                    choiceLabel.textColor = UIColor.darkText
                    choiceLabel.backgroundColor = UIColor.white
                    
                    choiceLabel.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.link.rawValue
                    choiceLabel.linkAttributes = [kCTForegroundColorAttributeName as AnyHashable : UIColor.blue.cgColor,kCTUnderlineStyleAttributeName as AnyHashable : NSNumber(value: true as Bool)]
                    choiceLabel.activeLinkAttributes = [NSForegroundColorAttributeName : UIColor.purple]
                    choiceLabel.delegate = parent
                    
                    choiceLabel.text = choice.text.trim().length > 0 ? choice.text : "\(NSLocalizedString("choice_choice", comment: "")) \(indexPath.row)"
                    
                    // Pro
                    proLabel.font = UIFont.systemFont(ofSize: 12)
                    proLabel.textColor = UIColor.darkText
                    proLabel.backgroundColor = UIColor.white
                    //Contra
                    contraLabel.font = UIFont.systemFont(ofSize: 12)
                    contraLabel.textColor = UIColor.darkText
                    contraLabel.backgroundColor = UIColor.white
                    
                    proLabel.text = ""
                    contraLabel.text = ""
                    
                    var proText = ""
                    var contraText = ""
                    
                    if let ratings = self.ratingsForChoice[choice] {
                        for rating in ratings {
                            if let participant = self.participantForRating[rating] {
                                self.statsCellHeight.cumulative += cell.bounds.height
                                self.statsCellHeight.count += 1
                                
                                if rating.rating == 1 {
                                    proText = proText + "\(participant.username)\n"
                                } else if rating.rating == -1 {
                                    contraText = contraText + "\(participant.username)\n"
                                }
                            }
                        }
                    }
                    proLabel.text = proText
                    contraLabel.text = contraText
                }
                
            }
            
            return cell
        }
    }
    
    class ParticipantsDataSource : NSObject, UITableViewDataSource {
        
        let questionId: String
        let choices: [Choice]
        let participants: [User]
        var ratingsForChoice: [Choice: [Rating]]
        let parent:StatsFragmentController
        
        init(questionId: String, choices: [Choice], participants: [User], ratingsForChoice: [Choice: [Rating]], parent: StatsFragmentController) {
            self.questionId = questionId
            self.choices = choices
            self.participants = participants
            self.ratingsForChoice = ratingsForChoice
            self.parent = parent
        }
        
        // Table view stuff
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            if self.parent.question!.isPublic {
                return 0
            } else if parent.moreThan50Participants {
                return 1
            } else{
                return self.participants.count
            }
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            if !parent.moreThan50Participants {
                if let participant = self.participants[safe: indexPath.row],
                    let cell = tableView.dequeueReusableCell(withIdentifier: "participantsCell") {
                    
                    let creatorText = cell.viewWithTag(101) as! UILabel
                    creatorText.text = participant.username
                    
                    let hasVotedText = cell.viewWithTag(102) as! UILabel
                    hasVotedText.text = NSLocalizedString("stats_voted_bool", comment: "")
                    
                    let creatorPic = cell.viewWithTag(103) as! UIImageView
                    creatorPic.layer.borderWidth = 0.0
                    creatorPic.layer.masksToBounds = false
                    creatorPic.layer.borderColor = UIColor.white.cgColor
                    creatorPic.layer.cornerRadius = 22
                    creatorPic.clipsToBounds = true
                    
                    creatorPic.image = participant.picture
                    if participant.photoId != nil && participant.picture == nil {
                        DispatchQueue.global(qos: .default).async {
                            participant.fetchPhoto({ (photo, error) in
                                creatorPic.image = photo
                            })
                        }
                    }
                    
                    cell.accessoryType = .none
                    
                    for choice in choices {
                        if let choiceRatings = self.ratingsForChoice[choice] {
                            for rating in choiceRatings {
                                if rating.raterId.rawId()! == participant.user_id {
                                    cell.accessoryType = .checkmark
                                }
                            }
                        }
                    }
                    
                    if(parent.participantsWhoLeft.contains(participant)){
                        hasVotedText.text = NSLocalizedString("has_left", comment: "")
                    }
                    
                    return cell
                }
                return UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "cell")
            } else {
                let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "cell")
                
                // Users who voted
                var voters = Set<Int>()
                for choice in choices {
                    if let choiceRatings = self.ratingsForChoice[choice] {
                        for rating in choiceRatings {
                            voters.insert(rating.raterId.rawId()!)
                        }
                    }
                }
                
                cell.textLabel?.text = NSString(format: NSLocalizedString("large_voting_notice", comment: "") as NSString, "\(parent.participantsCount)", "\(voters.count)") as String
                //                cell.textLabel?.text = NSLocalizedString("large_voting_notice", comment: "")
                cell.textLabel?.adjustsFontSizeToFitWidth = true
                cell.textLabel?.textAlignment = .center
                cell.textLabel?.numberOfLines = 1
                cell.textLabel?.backgroundColor = UIColor.clear
                cell.backgroundColor = UIColor.clear
                return cell
            }
        }
        
    }
    
    func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
        UIApplication.shared.openURL(url)
    }
    
    func tap(_ sender: UITapGestureRecognizer){
        let touchLocation = sender.location(ofTouch: 0, in: self.participantsTable)
        if let indexPath = self.participantsTable.indexPathForRow(at: touchLocation){
            if let participant = self.participantsDatasource?.participants[safe: indexPath.row], participant.user_id != GlobalQuestionData.user_id {
                
                let infoController = UIStoryboard(name: "Voting", bundle: nil).instantiateViewController(withIdentifier: "UserInfoController") as! UserInfoController
                infoController.set(user: participant)
                
                let userAlert = UIAlertController(title: "", message: nil, preferredStyle: UIAlertControllerStyle.alert)
                userAlert.setValue(infoController, forKey: "contentViewController")
                userAlert.addAction(UIAlertAction(title: NSLocalizedString("ok",comment:""), style: .default, handler: { alertAction in
                }))
                
                present(userAlert, animated: true, completion: nil)
                
            }
        }
    }
    
    func synced(lock: AnyObject, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
}
