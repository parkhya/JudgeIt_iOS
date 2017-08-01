//
//  StickerSheetController.swift
//  Judge it!
//
//  Created by Daniel Theveßen on 09.04.17.
//  Copyright © 2017 Judge it. All rights reserved.
//

import Foundation

class StickerSheetController : ImagePickerSheetController {
    
    let stickerAssets:[UIImage]
    let stickerHandler:(UIImage) -> Void
    
    init(title: String, stickerAssets: [UIImage], stickerHandler: @escaping (UIImage) -> Void){
        self.stickerAssets = stickerAssets
        self.stickerHandler = stickerHandler
        
        super.init(mediaType: .image)
        
        self.previewCollectionView.delegate = self
        self.previewCollectionView.dataSource = self
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func reloadCurrentPreviewHeight(invalidateLayout invalidate: Bool) {
        if stickerAssets.count <= 0 {
            sheetController.setPreviewHeight(0, invalidateLayout: invalidate)
        }
        else if stickerAssets.count > 0 && enlargedPreviews {
            sheetController.setPreviewHeight(2*maximumPreviewHeight, invalidateLayout: invalidate)
        }
        else {
            sheetController.setPreviewHeight(2*minimumPreviewHeight, invalidateLayout: invalidate)
        }
    }
    
    public override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return (stickerAssets.count+1)/2
    }
    
    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickerAssets.count - 2*section > 1 ? 2 : 1
    }
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(PreviewCollectionViewCell.self), for: indexPath) as! PreviewCollectionViewCell
        
        let asset = stickerAssets[2*indexPath.section + indexPath.item]
        cell.imageView.image = asset
        
        return cell
    }
    
    public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedAsset = stickerAssets[2*indexPath.section + indexPath.item]
        
        self.dismiss(animated: true, completion: {
             self.stickerHandler(selectedAsset)
        })
        
    }
    
    public override func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let asset = stickerAssets[2*indexPath.section + indexPath.item]
        let size = sizeForAsset(asset)
        
        // Scale down to the current preview height, sizeForAsset returns the original size
        let currentImagePreviewHeight = (sheetController.previewHeight/2) - 2 * previewInset
        let scale = currentImagePreviewHeight / size.height
        
        return CGSize(width: size.width * scale, height: currentImagePreviewHeight)
    }
    
    let minimumPreviewHeight: CGFloat = 96
    let maximumPreviewHeight: CGFloat = 96
    
    func sizeForAsset(_ asset: UIImage, scale: CGFloat = 1) -> CGSize {
        let proportion = CGFloat(asset.size.width)/CGFloat(asset.size.height)
        
        let imageHeight = maximumPreviewHeight - 2 * previewInset
        let imageWidth = floor(proportion * imageHeight)
        
        return CGSize(width: imageWidth * scale, height: imageHeight * scale)
    }
    
}
