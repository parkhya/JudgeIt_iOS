//
//  IntroPageViewController.swift
//  Judge it
//
//  Created by Daniel Thevessen on 30/01/16.
//  Copyright © 2016 Judge it. All rights reserved.
//

import Foundation

class IntroPageViewController : UIPageViewController, UIPageViewControllerDataSource {
    
    fileprivate(set) lazy var introViews: [UIViewController] = {
        return [self.newViewController(0), self.newViewController(1),
            self.newViewController(2), self.newViewController(3)]
    }()
    
    fileprivate func newViewController(_ index: Int) -> UIViewController {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "IntroViewController")
        (controller as! IntroViewController).passIndex(index)
        return controller
    }
    
    override func viewDidLoad() {
        dataSource = self
        
        if let firstViewController = introViews.first {
            setViewControllers([firstViewController], direction: .forward, animated: true, completion: nil)
        }
        
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?{
        return introViews[safe: (introViews.index(of: viewController) ?? -1) - 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?{
        return introViews[safe: (introViews.index(of: viewController) ?? introViews.count) + 1]
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return introViews.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        guard let firstViewController = viewControllers?.first,
            let firstViewControllerIndex = introViews.index(of: firstViewController) else {
                return 0
        }
        
        return firstViewControllerIndex
    }
    
}
