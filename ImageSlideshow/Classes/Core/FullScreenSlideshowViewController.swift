//
//  FullScreenSlideshowViewController.swift
//  ImageSlideshow
//
//  Created by Petr Zvoníček on 31.08.15.
//

import UIKit

@objcMembers
open class FullScreenSlideshowViewController: UIViewController {
    open var documentController: UIDocumentInteractionController?
    open var downloadTask: URLSessionDownloadTask?
    open var backgroundSession: URLSession?
    open var isView:Bool = false
    open var slideshow: ImageSlideshow = {
        let slideshow = ImageSlideshow()
        slideshow.zoomEnabled = true
        slideshow.contentScaleMode = UIViewContentMode.scaleAspectFit
        slideshow.activityIndicator = DefaultActivityIndicator()
        slideshow.pageIndicatorPosition = PageIndicatorPosition(horizontal: .center, vertical: .bottom)
        // turns off the timer
        slideshow.slideshowInterval = 0
        slideshow.autoresizingMask = [UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight]
        return slideshow
    }()
    
    
    /// Close button
    open var closeButton = UIButton()
    
    open var listUrl:[String] = []
    /// Close button frame
    open var closeButtonFrame: CGRect?
    
    open var dowloadButton = UIButton()
    
    open var dowloadFrame: CGRect?
    
    /// Closure called on page selection
    open var pageSelected: ((_ page: Int) -> Void)?
    open var pageDowloadSelected: ((_ page: Int) -> Void)?
    
    /// Index of initial image
    open var initialPage: Int = 0
    
    /// Input sources to
    open var inputs: [InputSource]?
    
    /// Background color
    open var backgroundColor = UIColor.black
    
    /// Enables/disable zoom
    open var zoomEnabled = true {
        didSet {
            slideshow.zoomEnabled = zoomEnabled
        }
    }
    
    
    fileprivate var isInit = true
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .custom
        if #available(iOS 13.0, *) {
            // Use KVC to set the value to preserve backwards compatiblity with Xcode < 11
            self.setValue(true, forKey: "modalInPresentation")
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = backgroundColor
        slideshow.backgroundColor = backgroundColor
        
        if let inputs = inputs {
            slideshow.setImageInputs(inputs)
        }
        
        view.addSubview(slideshow)
        
        // close button configuration
        closeButton.setImage(UIImage(named: "ic_cross_white", in: .module, compatibleWith: nil), for: UIControlState())
        closeButton.backgroundColor = .gray.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 20
        //        closeButton.layer.shadowColor = UIColor.black.cgColor
        //        closeButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        //        closeButton.layer.shadowRadius = 3
        //        closeButton.layer.shadowOpacity = 1
        closeButton.addTarget(self, action: #selector(FullScreenSlideshowViewController.close), for: UIControlEvents.touchUpInside)
        view.addSubview(closeButton)
        if !isView {
            // dowload Button Configuarion
            dowloadButton.setImage(UIImage(named: "ic_icon_dowload", in: .module, compatibleWith: nil), for: UIControlState())
            dowloadButton.backgroundColor = .gray.withAlphaComponent(0.5)
            dowloadButton.layer.cornerRadius = 20
            //        dowloadButton.layer.shadowColor = UIColor.black.cgColor
            //        dowloadButton.layer.shadowOffset = CGSize(width: 0, height: 0)
            //        dowloadButton.layer.shadowRadius = 3
            //        dowloadButton.layer.shadowOpacity = 1
            dowloadButton.addTarget(self, action: #selector(FullScreenSlideshowViewController.dowload), for: UIControlEvents.touchUpInside)
            view.addSubview(dowloadButton)
        }
        
       
    }
    
    override open var prefersStatusBarHidden: Bool {
        return true
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isInit {
            isInit = false
            slideshow.setCurrentPage(initialPage, animated: false)
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        slideshow.slideshowItems.forEach { $0.cancelPendingLoad() }
        
        // Prevents broken dismiss transition when image is zoomed in
        slideshow.currentSlideshowItem?.zoomOut()
    }
    
    open override func viewDidLayoutSubviews() {
        if !isBeingDismissed {
            let safeAreaInsets: UIEdgeInsets
            if #available(iOS 11.0, *) {
                safeAreaInsets = view.safeAreaInsets
            } else {
                safeAreaInsets = UIEdgeInsets.zero
            }
            
            closeButton.frame = closeButtonFrame ?? CGRect(x: max(10, safeAreaInsets.left), y: max(10, safeAreaInsets.top), width: 40, height: 40)
            dowloadButton.frame = dowloadFrame ?? CGRect(x: self.view.bounds.width - 50, y: max(safeAreaInsets.top, 10), width: 40,  height: 40)
        }
        
        slideshow.frame = view.frame
    }
    
    func close() {
        // if pageSelected closure set, send call it with current page
        if let pageSelected = pageSelected {
            pageSelected(slideshow.currentPage)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func dowload() {
        if let pageDowloadSelected = pageDowloadSelected {
            pageDowloadSelected(slideshow.currentPage)
        }
        if let url = URL(string: listUrl[slideshow.currentPage]){
            downloadAndShowSaveAsDialog(url: url)
        }
    }
}
extension FullScreenSlideshowViewController: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController) -> UIViewController {
            return self
        }
    
}
extension FullScreenSlideshowViewController:  URLSessionDelegate{
    func downloadAndShowSaveAsDialog(url:URL) {
        let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator .center = view.center // Đặt vị trí cho indicator
        activityIndicator.hidesWhenStopped = true // Ẩn indicator khi không hoạt động
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        let session = URLSession.shared
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                print( "Error downloading file: \(error)")
//                activity?.hide()
                activityIndicator.stopAnimating()

                return
            }
            
            if let data = data{
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                do {
                    try data.write(to: fileURL)
                    DispatchQueue.main.async {
                        // Initialize the document controller and set its delegate
                        self.documentController = UIDocumentInteractionController(url: fileURL)
                        self.documentController?.delegate = self
                        if let controller = self.documentController {
                            // Show the "Open In" menu
                            if !controller.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true) {
                                // Handle the case where no apps are available to open the file
                                print("No apps available to open the file.")
                            } else {
                            }
                        }
                        activityIndicator.stopAnimating()
//                        activity?.hide()
                    }
                } catch {
                    activityIndicator.stopAnimating()
//                    activity?.hide()
                    print( "Error downloading file: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
    
}
