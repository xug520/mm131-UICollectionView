//
//  PhotoBrowserCollectionViewController.swift
//  1000meitu
//
//  Created by lu on 15/8/24.


import Foundation
import UIKit
import Alamofire
import Kanna
import Photos
import JGProgressHUD
import MBProgressHUD
import SDWebImage

class PhotoBrowserCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UIActionSheetDelegate, BrowserCellDelagate{
    
    var photos = NSMutableOrderedSet()
    
    //给cell定义名称，在cell的属性上也要定义为同一个名称
    let PhotoBrowserCellIdentifier = "PhotoBrowserCell"
    var populatingPhotos = false //是否在获取图片
    var currentPage = 1 //当前页数
    var currentType: PageType = .qingchun //默认的type为qingchun
    var forumId: Int = 0 //forum id
    var photoInfo: PhotoInfo = PhotoInfo() //保存图片信息
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initData()
        setupView()
        populatePhotos()

    }
    
    //获取到这个forum的id，比如http://www.mm131.com/xiaohua/2001.html的forumid为2001
    func initData(){
        forumId = getForumId()
    }
    
    func setupView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.bounds.size.width, height: view.bounds.size.height)
        layout.scrollDirection = UICollectionViewScrollDirection.Horizontal
        collectionView!.pagingEnabled = true
        collectionView!.directionalLockEnabled = true
        collectionView!.collectionViewLayout = layout
        self.collectionView!.registerClass(PhotoBrowserCollectionViewCell.self, forCellWithReuseIdentifier: PhotoBrowserCellIdentifier)
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        //添加下载baritem
        addButtomBar()
        
        //为了消除载入时候竖直方向上的位移
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    //单击隐藏navigationbar和tabbar
    func singleTap() {
        let state = self.navigationController?.navigationBarHidden
        self.navigationController?.setNavigationBarHidden(!state!, animated: true)
        self.navigationController?.setToolbarHidden(!state!, animated: true)
    }
    
    func addButtomBar() {
        var items = [UIBarButtonItem]()
        
        //填充空白
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        
        items.append(flexibleSpace)
        //只有这样图片才不会显示为纯蓝色
        var image = UIImage(named: "Download")
        image = image?.imageWithRenderingMode(UIImageRenderingMode.AlwaysOriginal)
        let downloadItem = UIBarButtonItem(image: image, style: UIBarButtonItemStyle.Plain, target: self, action: "saveImage:")
        downloadItem.tintColor = UIColor.whiteColor()
        items.append(downloadItem)
        items.append(flexibleSpace)

        self.setToolbarItems(items, animated: true)
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    //设置HUD
    func loadTextHUD(text: String, time: Float){
        let loadingNotification = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        loadingNotification.mode = MBProgressHUDMode.Text
        loadingNotification.minShowTime = time
        loadingNotification.labelText = text
    }
    
    //保存图片
    func saveImage(sender: AnyObject){
        let indexPath = collectionView!.indexPathsForVisibleItems().last!
        let cell = collectionView?.cellForItemAtIndexPath(indexPath) as! PhotoBrowserCollectionViewCell
        if cell.imageView.image == nil{
            print("image nil")
        }else{
            UIImageWriteToSavedPhotosAlbum(cell.imageView.image!, self, "image:didFinishSavingWithError:contextInfo:", nil)
        }
    }
    
    func image(image:UIImage,didFinishSavingWithError error:NSError?,contextInfo:AnyObject?) {
        if error == nil{
            print("保存成功")
            showSuccessMsg("保存成功", interval: 0.5)
        }else{
            print("保存失败")
            showErrorMsg("保存失败", interval: 0.5)
        }
    }
    
    //展示消息
    func showSuccessMsg(text: String, interval: Double){
        let hud = JGProgressHUD(style: JGProgressHUDStyle.Light)
        hud.textLabel.text = text
        hud.indicatorView = JGProgressHUDSuccessIndicatorView()
        hud.showInView(self.view, animated: true)
        hud.dismissAfterDelay(interval, animated: true)
    }
    
    func showErrorMsg(text: String, interval: Double){
        let hud = JGProgressHUD(style: JGProgressHUDStyle.Light)
        hud.textLabel.text = text
        hud.indicatorView = JGProgressHUDErrorIndicatorView()
        hud.showInView(self.view, animated: true)
        hud.dismissAfterDelay(interval, animated: true)
    }

    //获取forumid
    func getForumId()->Int{
        if !photoInfo.forumUrl.componentsSeparatedByString(Router.PhotoPage(currentType, 0).pageSource).isEmpty{
            let array = photoInfo.forumUrl.componentsSeparatedByString(Router.PhotoPage(currentType, 0).pageSource)
            let temp = array[1].componentsSeparatedByString(".html")
            return Int(temp[0])!
        }
        
        return 0 //invalid
    }
    
    //组装页面的url
    func getPageUrl()->String{
        var url = Router.PhotoPage(currentType, currentPage).pageSource + "\(forumId)"
        if currentPage > 1{
            url += "_" + "\(currentPage)" + ".html"
        }else{
            url += ".html"
        }
        
        return url
    }
    
    //对获取到的图片进行筛选
    func checkImageUrl(imageUrl: String?)->Bool{
        if imageUrl == nil{
            return false
        }
        
        if !imageUrl!.componentsSeparatedByString("\(forumId)").isEmpty{
            let array = imageUrl!.componentsSeparatedByString("\(forumId)")
            if array.count > 1{
                return true
            }
        }
        
        return false
    }
    
    //获取图片
    func populatePhotos(){
        if populatingPhotos{//正在获取，则返回
            print("return back")
            return
        }
        
        populatingPhotos = true

        let pageUrl = getPageUrl()
        Alamofire.request(.GET, pageUrl).validate().responseString{
            (request, response, result) in
            let isSuccess = result.isSuccess
            let html = result.value
            if isSuccess == true{
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
                    if let doc = Kanna.HTML(html: html!, encoding: NSUTF8StringEncoding){
                        CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingASCII)
                        let lastItem = self.photos.count
                        for node in doc.css("img"){
                            if self.checkImageUrl(node["src"]){
                                self.photos.addObject(node["src"]!)
                                break
                            }
                        }
                
                        let indexPaths = (lastItem..<self.photos.count).map { NSIndexPath(forItem: $0, inSection: 0) }
                        dispatch_async(dispatch_get_main_queue()) {
                            self.collectionView!.insertItemsAtIndexPaths(indexPaths)
                        }
                        self.currentPage++
                    }
                }
            }

            self.populatingPhotos = false
        }
    }
    
    
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.photos.count
    }
    
    //左右间距
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return CGFloat(0)
    }
    
    //上下间距
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return CGFloat(0)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(PhotoBrowserCellIdentifier, forIndexPath: indexPath) as! PhotoBrowserCollectionViewCell
        cell.delegate = self
        let imageURL = NSURL(string: photos.objectAtIndex(indexPath.row) as! String)
        
        //复用时先置为nil，使其不显示原有图片
        cell.imageView.image = nil

        let loadingNotification = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        loadingNotification.mode = MBProgressHUDMode.Indeterminate
        loadingNotification.labelText = "加载中..."
        cell.imageView.sd_setImageWithURL(imageURL, completed: { (image, error, cacheType, url) -> Void in
            MBProgressHUD.hideHUDForView(self.view, animated: false)
            if image == nil{
                return
            }

            if indexPath.row + 2 >= self.currentPage{
                self.populatePhotos()
            }
        })
        
        return cell
    }
}