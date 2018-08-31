/*
 * Copyright (C) 2016 nohana, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an &quot;AS IS&quot; BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import Photos

class AssetListViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    weak var nohanaImagePickerController: NohanaImagePickerController?
    var photoKitAssetList: PhotoKitAssetList!

    let longPressGestureRecognizer: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
    let tapGestureRecognizer: UITapGestureRecognizer = UITapGestureRecognizer()
    var isGestureEnabled: Bool = false
    var selectedIndexFromLongPress: IndexPath? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = nohanaImagePickerController?.config.color.background ?? .white
        if let _nohanaImagePickerController = nohanaImagePickerController {
            if _nohanaImagePickerController.pressAndHoldToPreview {
                enableGestureRecogniser(nohanaImagePickerController: _nohanaImagePickerController)
            }
        }
        updateTitle()
        setUpToolbarItems()
        addPickPhotoKitAssetNotificationObservers()
    }

    var cellSize: CGSize {
        guard let nohanaImagePickerController = nohanaImagePickerController else {
            return CGSize.zero
        }
        var numberOfColumns = nohanaImagePickerController.numberOfColumnsInLandscape
        if UIInterfaceOrientationIsPortrait(UIApplication.shared.statusBarOrientation) {
            numberOfColumns = nohanaImagePickerController.numberOfColumnsInPortrait
        }
        let cellMargin: CGFloat = 2
        let cellWidth = (view.frame.width - cellMargin * (CGFloat(numberOfColumns) - 1)) / CGFloat(numberOfColumns)
        return CGSize(width: cellWidth, height: cellWidth)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let nohanaImagePickerController = nohanaImagePickerController {
            setToolbarTitle(nohanaImagePickerController)
        }
        collectionView?.reloadData()
        scrollCollectionViewToInitialPosition()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.isHidden = true
        coordinator.animate(alongsideTransition: nil) { _ in
            // http://saygoodnight.com/2015/06/18/openpics-swift-rotation.html
            if self.navigationController?.visibleViewController != self {
                self.view.frame = CGRect(x: self.view.frame.origin.x, y: self.view.frame.origin.y, width: size.width, height: size.height)
            }
            self.collectionView?.reloadData()
            self.scrollCollectionViewToInitialPosition()
            self.view.isHidden = false
        }
    }

    var isFirstAppearance = true

    func updateTitle() {
        title = photoKitAssetList.title
    }
    
    func enableGestureRecogniser(nohanaImagePickerController: NohanaImagePickerController) {
        longPressGestureRecognizer.addTarget(self, action: #selector(didLongPress(_:)))
        longPressGestureRecognizer.minimumPressDuration = nohanaImagePickerController.minimumPressDuration
        longPressGestureRecognizer.delaysTouchesBegan = true
        longPressGestureRecognizer.delegate = self
        collectionView?.addGestureRecognizer(longPressGestureRecognizer)
        
        tapGestureRecognizer.addTarget(self, action: #selector(didTapCell(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        collectionView?.addGestureRecognizer(tapGestureRecognizer)
        
        isGestureEnabled = true
    }

    func scrollCollectionView(to indexPath: IndexPath) {
        let count: Int? = photoKitAssetList?.count
        guard count != nil && count! > 0 else {
            return
        }
        DispatchQueue.main.async {
            self.collectionView?.scrollToItem(at: indexPath, at: .bottom, animated: false)
        }
    }

    func scrollCollectionViewToInitialPosition() {
        guard isFirstAppearance else {
            return
        }
        let indexPath = IndexPath(item: self.photoKitAssetList.count - 1, section: 0)
        self.scrollCollectionView(to: indexPath)
        isFirstAppearance = false
    }

    // MARK: - UICollectionViewDataSource

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoKitAssetList.count
    }

    // MARK: - UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !isGestureEnabled {
            if let nohanaImagePickerController = nohanaImagePickerController {
                nohanaImagePickerController.delegate?.nohanaImagePicker?(nohanaImagePickerController, didSelectPhotoKitAsset: photoKitAssetList[indexPath.item].originalAsset)
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AssetCell", for: indexPath) as? AssetCell,
            let nohanaImagePickerController  = nohanaImagePickerController else {
                fatalError("failed to dequeueReusableCellWithIdentifier(\"AssetCell\")")
        }
        cell.tag = indexPath.item
        cell.update(asset: photoKitAssetList[indexPath.row], nohanaImagePickerController: nohanaImagePickerController)

        let imageSize = CGSize(
            width: cellSize.width * UIScreen.main.scale,
            height: cellSize.height * UIScreen.main.scale
        )
        let asset = photoKitAssetList[indexPath.item]
        asset.image(targetSize: imageSize) { (imageData) -> Void in
            DispatchQueue.main.async(execute: { () -> Void in
                if let imageData = imageData {
                    if cell.tag == indexPath.item {
                        cell.imageView.image = imageData.image
                    }
                }
            })
        }
        return (nohanaImagePickerController.delegate?.nohanaImagePicker?(nohanaImagePickerController, assetListViewController: self, cell: cell, indexPath: indexPath, photoKitAsset: asset.originalAsset)) ?? cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }

    // MARK: - Storyboard

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var selectedIndexPath: IndexPath? = nil
        
        if !isGestureEnabled {
            selectedIndexPath = collectionView?.indexPathsForSelectedItems?.first
        } else {
            selectedIndexPath = selectedIndexFromLongPress
            selectedIndexFromLongPress = nil
        }
        
        guard let indexPath = selectedIndexPath else {
            return
        }
        
        let assetListDetailViewController = segue.destination as! AssetDetailListViewController
        assetListDetailViewController.photoKitAssetList = photoKitAssetList
        assetListDetailViewController.nohanaImagePickerController = nohanaImagePickerController
        assetListDetailViewController.currentIndexPath = indexPath
    }

    // MARK: - IBAction
    @IBAction func didPushDone(_ sender: AnyObject) {
        let pickedPhotoKitAssets = nohanaImagePickerController!.pickedAssetList.map { ($0 as! PhotoKitAsset).originalAsset }
        nohanaImagePickerController!.delegate?.nohanaImagePicker(nohanaImagePickerController!, didFinishPickingPhotoKitAssets: pickedPhotoKitAssets )
    }
}

extension AssetListViewController: UIGestureRecognizerDelegate {
    @objc func didTapCell(_ gesture: UIGestureRecognizer) {
        let point = gesture.location(in: self.collectionView)
        guard let indexPath = self.collectionView?.indexPathForItem(at: point),
            let cell = self.collectionView?.cellForItem(at: indexPath) as? AssetCell else {
                return
        }
        cell.pickOrDropAsset()
    }
    
    @objc func didLongPress(_ gesture: UIGestureRecognizer) {
        let point = gesture.location(in: self.collectionView)
        guard let indexPath = self.collectionView?.indexPathForItem(at: point) else {
                return
        }
        
        switch gesture.state {
        case .began:
            selectedIndexFromLongPress = indexPath
            performSegue(withIdentifier: "AssetDetailListViewController", sender: self)
        default:
            break
        }
    }
}
