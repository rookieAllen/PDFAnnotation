
//
//  PdfViewController.swift
//  SmartSwift
//
//  Created by kc64862 on 2017/09/25.
//  Copyright © 2017年 kc64862. All rights reserved.
//

import AVFoundation
import CoreGraphics
import Foundation
import UIKit
import PDFKit

//MARK: - class

@available(iOS 11.0, *)
class PdfManageViewController: UIViewController,
    UIScrollViewDelegate,
    PDFDocumentDelegate,
    PDFViewDelegate,
    penTouchDelegate{
    
    //MARK: - property
    var documentPath: String?
    
    var startPage = 1          // 初期表示するページ
    var maxPages = 0           // PDFの最大ページ
    var pageLength = 0         // お気に入りのページ単位 = 1、ファイル単位 = 0
    var nowPage = 0            // PDFの現在表示されているページ
    
    var scrollBeginingPoint: CGPoint! //ScrollViewの現在表示されている場所
    
    var docs:CGPDFDocument?
    var docs_pdf:PDFDocument?
    
    var startPoint : CGPoint!                      //PDFSelectionの出発点
    var endPoint : CGPoint!                        //PDFSelectionの終点
    var currentPoint : CGPoint!                    //PDFSelection現在のポイント
    var isHighlited : Bool = false                 //ハイライトかどうか
    var isUnderline : Bool = false                 //下線かどうか
    var undoAnnotation : [Int] = []                //元に戻す配列
    var lastSelection : [CGRect] = []
    var currentSelection : [CGRect] = []
    var totalBounds : [CGRect] = []
    
    //ベースとなるUIScrollView.このビューでページめくりを行う
    let baseScrollView = BaseScrollView()
    let topToolbarView    = UIView()
    
    let kMaxDisplayView      = 1           //ページ最大保持数 （表示ページの前後に何ページ表示するか）
    let kTagPdfView          = 4000000     //PDFViewのtagのスタート番号.ScrollViewのtag番号と明示的に分けるため
    let kTagCanvasView       = 8000000     //CanvesView(メモ書きのView)のtagのスタート番号.ScrollViewのtag番号と明示的に分けるため
    let kTagImageView        = 20000000    //イメージのViewタグ
    let kTagPointerView      = 6000000     //PointerViewのtagのスタート番号
    let kTagResultMarkView   = 10000000    //検索結果をマークするViewのtagスタート番号
    let kTagCanvasStickyView = 18000000    //付箋用のViewタグ
    
    let markButton = UIButton()            //ハイライトボタン
    let underlineButton = UIButton()       //下線ボタン
    let undoButton = UIButton()            //元に戻すボタン
    
    var pdfPageViewDict  = Dictionary<Int, UIScrollView>() //ScrollView（各ページ）を格納
    var pdfPageAnnotationDict = Dictionary<Int, Array<Int>>()       //PDFAnnotation（各ページ）を格納
    var undoAnnotationDict = Dictionary<Int, Array<CGRect>>()       //元に戻す配列
    
    
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var sizeAvr: Double = 0.0  //1ページの平均容量
    
    
    //MARK: - default or override
    
    override func loadView() {
        super.loadView()
        
        //ドキュメントパスの生成
        self.documentPath = Bundle.main.path(forResource: "U3DElements", ofType: "pdf")
        
        autoreleasepool{
            
            docs = CGPDFDocument.init((NSURL(fileURLWithPath: self.documentPath!) as CFURL))
            docs_pdf = PDFDocument(url: URL(fileURLWithPath: self.documentPath!))
            
            //現在の表示ページ
            self.nowPage = 1
            //最大ページ数
            self.maxPages = (docs_pdf?.pageCount)!
            
        } // end of autoreleasepool.
        
        self.view.backgroundColor = UIColor.lightGray
        
        //▼PDFViewの作成
        
        //ファイルリンクで存在しないページ数を指定された場合
        if self.nowPage > self.maxPages {
            self.nowPage = self.maxPages
        }
        
        //▼ベースとなるScrollViewの設定
        baseScrollView.delegate = self
        //baseScrollView.penDelegate = self
        baseScrollView.backgroundColor = UIColor.clear
        baseScrollView.minimumZoomScale = 1
        baseScrollView.maximumZoomScale = 1
        baseScrollView.isPagingEnabled = true
        baseScrollView.isMultipleTouchEnabled = true
        baseScrollView.delaysContentTouches = false
        //baseScrollView.canCancelContentTouches = false
        baseScrollView.bounces = true
        baseScrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        baseScrollView.showsHorizontalScrollIndicator = false
        baseScrollView.showsVerticalScrollIndicator = false
        baseScrollView.contentSize = CGSize(width: (self.app.window!.bounds.width) / 1.0 * CGFloat(maxPages),
                                            height: (self.app.window!.bounds.height))
        baseScrollView.isUserInteractionEnabled = true
        
        self.view.addSubview(baseScrollView)
        baseScrollView.translatesAutoresizingMaskIntoConstraints = false
        baseScrollView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        baseScrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        baseScrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        baseScrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        
        let attributes: Dictionary = try! FileManager.default.attributesOfItem(atPath: self.documentPath!)
        
        //1ページの平均値を算出
        let originalFileSize: Double = Double(attributes[FileAttributeKey.size] as! Int) / 1024.0
        let numberOfPages: Double = Double((docs_pdf?.pageCount)!)
        self.sizeAvr = originalFileSize / numberOfPages
        
        //toolbarView
        topToolbarView.backgroundColor = UIColor.init(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.5)
        self.view.addSubview(topToolbarView)
        topToolbarView.translatesAutoresizingMaskIntoConstraints = false
        topToolbarView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        topToolbarView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        topToolbarView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        topToolbarView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        //ハイライトボタン
        markButton.setImage(UIImage(named:"highlight"), for: .normal)
        markButton.backgroundColor = UIColor.clear
        markButton.frame = CGRect(x: 75, y: 10, width: 30, height: 30)
        markButton.addTarget(self, action: #selector(onTapMarkButton(sender:)), for: .touchUpInside)
        markButton.titleEdgeInsets = UIEdgeInsetsMake(0, -20, 0, -20)
        markButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        markButton.isExclusiveTouch = true
        topToolbarView.addSubview(markButton)
        
        //下線ボタン
        underlineButton.setImage(UIImage(named:"underline"), for: .normal)
        underlineButton.backgroundColor = UIColor.clear
        underlineButton.frame = CGRect(x: 175, y: 10, width: 30, height: 30)
        underlineButton.addTarget(self, action: #selector(onTapUnderlineButton(sender:)), for: .touchUpInside)
        underlineButton.titleEdgeInsets = UIEdgeInsetsMake(0, -20, 0, -20)
        underlineButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        underlineButton.isExclusiveTouch = true
        topToolbarView.addSubview(underlineButton)
        
        //元に戻すボタン
        undoButton.setImage(UIImage(named:"undo"), for: .normal)
        undoButton.backgroundColor = UIColor.clear
        undoButton.addTarget(self, action: #selector(onTapUndoButton(sender:)), for: .touchUpInside)
        undoButton.titleEdgeInsets = UIEdgeInsetsMake(0, -20, 0, -20)
        undoButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        undoButton.isExclusiveTouch = true
        topToolbarView.addSubview(undoButton)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    deinit {
        NSLog("PDFManagerViewControllerは正しく解放されました")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
    }
    
    override func viewDidAppear(_ animated: Bool) {     //NSLog("viewDidAppear")
        super.viewDidAppear(animated)
        
        self.buildPage(isCreatePdf: true)
        //ページスクロールの位置を設定する
        var point: CGPoint = CGPoint.zero
        
        if let keyWindow = UIApplication.shared.keyWindow {
            let width: CGFloat = keyWindow.bounds.width
            
            point = CGPoint(x: width / 1 * CGFloat((nowPage - 1)),
                            y: baseScrollView.contentOffset.y)
        }
        baseScrollView.contentOffset = point
    }
    
    override func viewDidLayoutSubviews() {     //NSLog("viewDidLayoutSubviews")
        super.viewDidLayoutSubviews()
        
        self.view.frame = app.window!.bounds
        
        self.undoButton.frame = CGRect(x: self.view.frame.width - 100, y: 10, width: 30, height: 30)
        
        //画面の再構成
        self.reloadDisplay()
    }
    
    //MARK: - Event ページめくり関連
    
    //スワイプ開始時
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        let targetAddPage = 1
        
        if let targetPdfViewNext = self.view.viewWithTag(nowPage + targetAddPage + kTagPdfView) {
            targetPdfViewNext.sizeToFit()
            targetPdfViewNext.setNeedsDisplay()
            targetPdfViewNext.layoutIfNeeded()
        }
        if let targetPdfViewRev = self.view.viewWithTag(nowPage - targetAddPage + kTagPdfView) {
            targetPdfViewRev.sizeToFit()
            targetPdfViewRev.setNeedsDisplay()
            targetPdfViewRev.layoutIfNeeded()
        }
    }
    
    //スワイプ完了後ページめくりを行う
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        if let _ = scrollView as? DocumentScrollView {
            
            let targetAddPage = 1
            
            if let targetPdfViewNext = self.view.viewWithTag(nowPage + targetAddPage + kTagPdfView) {
                targetPdfViewNext.sizeToFit()
                targetPdfViewNext.setNeedsDisplay()
                targetPdfViewNext.layoutIfNeeded()
                
            }
            if let targetPdfViewRev = self.view.viewWithTag(nowPage - targetAddPage + kTagPdfView) {
                targetPdfViewRev.sizeToFit()
                targetPdfViewRev.setNeedsDisplay()
                targetPdfViewRev.layoutIfNeeded()
            }
            
            return
        }
        
        if scrollView.tag == self.maxPages + 10 {
            //PDF選択一覧表示中にスクロールが反応するのをここで回避する
            self.baseScrollView.isUserInteractionEnabled = true
            return
        }
        
        //１ページ資料は終了
        if self.maxPages == 1 {
            return
        }
        
        let pageCheck = Double((scrollView.contentOffset.x / ((UIApplication.shared.keyWindow?.bounds.width)!)) + 1)
        if !(abs(pageCheck.truncatingRemainder(dividingBy: 1.0)).isLess(than: .ulpOfOne)) {
            //ページ算出が小数点有りの場合はページめくりとしない
            return
        }
        
        let newPage = Int(pageCheck)
        if newPage == self.nowPage {
            //ページが変わってないときは終了
            return
        }
        
        //ズームを戻す
        let targetView = self.view.viewWithTag(nowPage) as! UIScrollView
        targetView.zoomScale = 1.0
        
        self.nowPage = Int(newPage)
        
        //ページの設定
        self.buildPage()
        
        //NSLog("AAAAAAAAAAAAAAAAA:\(self.nowPage)")
        
        if let targetPdfView = self.view.viewWithTag(self.nowPage + self.kTagPdfView) as? PreviewPDFView {
            targetPdfView.sizeToFit()
            targetPdfView.setNeedsDisplay()
            targetPdfView.layoutIfNeeded()
        }
        
        //現在のAnnotation情報をクリアする
        self.undoAnnotation.removeAll()
        
        //現在のページはAnnotationが追加された場合、そのAnnotation情報を変数にセットする
        if (self.pdfPageAnnotationDict[nowPage] != nil) {
            self.undoAnnotation = self.pdfPageAnnotationDict[nowPage]!
        }
    }
    
    //MARK: - Event メモ書き関連
    //クリックハイライトボタン
    func onTapMarkButton(sender: UIButton) {
        if (self.isHighlited) {
            self.isHighlited = false
            self.markButton.setImage(UIImage(named:"highlight"), for: .normal)
            self.markButton.layer.borderWidth = 0
        } else {
            self.isHighlited = true
            self.markButton.setImage(UIImage(named:"highlight_selected"), for: .normal)
            self.markButton.layer.borderColor = UIColor.red.cgColor
            self.markButton.layer.borderWidth = 2
            
            self.underlineButton.setImage(UIImage(named:"underline"), for: .normal)
            self.underlineButton.layer.borderWidth = 0
            self.isUnderline = false
        }
        //メモ書きモードをオンにする
        let targetScrollView = self.view.viewWithTag(nowPage) as! DocumentScrollView
        
        baseScrollView.isScrollEnabled = !isHighlited
        targetScrollView.isScrollEnabled = !isHighlited
        
        //スクロールビューのPanジェスチャーの無効化
        for gesture in targetScrollView.gestureRecognizers! {
            if gesture.isKind(of: UIPanGestureRecognizer.self) {
                gesture.isEnabled = !isHighlited
            }
            if gesture.isKind(of: UITapGestureRecognizer.self) {
                gesture.isEnabled = !isHighlited
            }
        }
        
        //付箋View（最上位）のタッチイベントを有効にする
        let targetCanvasStickyView = self.view.viewWithTag(nowPage + kTagCanvasStickyView) as! StickyBaseView
        targetCanvasStickyView.isUserInteractionEnabled = isHighlited
        
        //设定markerMode
        let targetPdfView = self.view.viewWithTag(self.nowPage + kTagPdfView) as! PreviewPDFView
        targetPdfView.isMarkerMode = isHighlited
    }
    
    //クリック下線ボタン
    func onTapUnderlineButton(sender:UIButton) {
        if (self.isUnderline) {
            self.isUnderline = false
            self.underlineButton.setImage(UIImage(named:"underline"), for: .normal)
            self.underlineButton.layer.borderWidth = 0
        } else {
            self.isUnderline = true
            self.underlineButton.setImage(UIImage(named:"underline_selected"), for: .normal)
            self.underlineButton.layer.borderColor = UIColor.red.cgColor
            self.underlineButton.layer.borderWidth = 2
            
            self.markButton.setImage(UIImage(named:"highlight"), for: .normal)
            self.markButton.layer.borderWidth = 0
            self.isHighlited = false
        }
        
        //メモ書きモードをオンにする
        let targetScrollView = self.view.viewWithTag(nowPage) as! DocumentScrollView
        
        baseScrollView.isScrollEnabled = !isUnderline
        targetScrollView.isScrollEnabled = !isUnderline
        
        //スクロールビューのPanジェスチャーの無効化
        for gesture in targetScrollView.gestureRecognizers! {
            if gesture.isKind(of: UIPanGestureRecognizer.self) {
                gesture.isEnabled = !isUnderline
            }
            if gesture.isKind(of: UITapGestureRecognizer.self) {
                gesture.isEnabled = !isUnderline
            }
        }
        
        //付箋View（最上位）のタッチイベントを有効にする
        let targetCanvasStickyView = self.view.viewWithTag(nowPage + kTagCanvasStickyView) as! StickyBaseView
        targetCanvasStickyView.isUserInteractionEnabled = isUnderline
        
        //设定markerMode
        let targetPdfView = self.view.viewWithTag(self.nowPage + kTagPdfView) as! PreviewPDFView
        targetPdfView.isMarkerMode = isUnderline
    }
    
    //クリック元に戻すボタン
    func onTapUndoButton(sender:UIButton) {
        //メモモードのときはメモ書き設定を行う
        let targetPdfView = self.view.viewWithTag(nowPage + kTagPdfView) as! PreviewPDFView
        
        if (self.pdfPageAnnotationDict[nowPage]!.count > 0) {
            //最後に追加されたAnnotationを削除する
            let count: Int = (self.pdfPageAnnotationDict[nowPage]?.last)!
            for _ in 1 ... count {
                //touchesBeganからtouchesEndまでに追加された複数のAnnotationをすべて削除する
                let lastAnnotation = targetPdfView.currentPage?.annotations.last
                targetPdfView.currentPage?.removeAnnotation(lastAnnotation!)
            }
            self.pdfPageAnnotationDict[nowPage]?.removeLast()
            
            if (self.undoAnnotation.last != nil) {
                self.undoAnnotation.removeLast()
            }
        }
        
        //元に戻すボタンの活性・非活性を制御する
        if (self.pdfPageAnnotationDict[nowPage]!.count > 0) {
            self.undoButton.isEnabled = true
        } else {
            self.undoButton.isEnabled = false
        }
    }
    
    //次のページへ移動
    func changeNextPage(isMemoSetting: Bool) {
        
        if nowPage == maxPages {
            return
        }
        
        //ズームを戻す
        let targetView = self.view.viewWithTag(nowPage) as! UIScrollView
        targetView.zoomScale = 1.0
        
        self.nowPage += 1
        
        //ページの設定
        self.buildPage()
        
        //メモモードのときはメモ書き設定を行う
        let targetPdfView = self.view.viewWithTag(self.nowPage + kTagPdfView) as! PreviewPDFView
        
        //ページスクロールの位置を設定する
        baseScrollView.contentOffset = CGPoint(x: (UIApplication.shared.keyWindow?.bounds.width)! / CGFloat((nowPage - 1)),
                                               y: baseScrollView.contentOffset.y)
        
        
        targetPdfView.sizeToFit()
        targetPdfView.setNeedsDisplay()
        targetPdfView.layoutIfNeeded()
    }
    
    //前のページへ移動
    func changePrevPage(isMemoSetting: Bool) {
        
        if nowPage == 1 {
            return
        }
        
        //ズームを戻す
        let targetView = self.view.viewWithTag(nowPage) as! UIScrollView
        targetView.zoomScale = 1.0
        
        self.nowPage -= 1
        
        //ページの設定
        self.buildPage()
        
        let targetPdfView = self.view.viewWithTag(self.nowPage + kTagPdfView) as! PreviewPDFView
        
        targetPdfView.sizeToFit()
        targetPdfView.setNeedsDisplay()
        targetPdfView.layoutIfNeeded()
        
        //ページスクロールの位置を設定する
        baseScrollView.contentOffset = CGPoint(x: (UIApplication.shared.keyWindow?.bounds.width)! / CGFloat((nowPage - 1)),
                                               y: baseScrollView.contentOffset.y)
    }
    
    //PDFページにAnnotation(ハイライト、下線など)を追加
    func addAnnotations(bounds: CGRect, mode: String, targetPdfView: PreviewPDFView) {
        var annotation : PDFAnnotation = PDFAnnotation()
        //ハイライトする
        if (isHighlited) {
            annotation = PDFAnnotation(bounds: bounds,
                                       forType: PDFAnnotationSubtype.highlight,
                                       withProperties: nil)
            annotation.color = UIColor.yellow
            annotation.backgroundColor = UIColor.clear
        }
        
        //下線を追加する
        if (isUnderline) {
            annotation = PDFAnnotation(bounds: bounds,
                                       forType: PDFAnnotationSubtype.underline,
                                       withProperties: nil)
            let border = PDFBorder()
            border.lineWidth = 2.0
            annotation.border = border
            annotation.color = UIColor.red
        }
        
        //let targetPdfView = self.view.viewWithTag(self.nowPage + self.kTagPdfView) as? PreviewPDFView
        targetPdfView.currentPage?.addAnnotation(annotation)
        
        if (mode == "began") {
            //touchesBeganの時、追加されたAnnotation数を1とする
            self.undoAnnotation.append(1)
        } else {
            //追加されたAnnotation数に1を加算する
            let cnt = self.undoAnnotation.last! + 1
            self.undoAnnotation.removeLast()
            self.undoAnnotation.append(cnt)
            self.currentSelection.append(bounds)
        }
        
        self.undoButton.isEnabled = true
    }
    
    // タッチイベントの検出
    func _touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let targetPdfView = self.view.viewWithTag(self.nowPage + self.kTagPdfView) as? PreviewPDFView
        let targetView = self.view.viewWithTag(self.nowPage + self.kTagCanvasStickyView) as! StickyBaseView
        
        let allTouches = (touches as NSSet).allObjects
        let startTouch = allTouches[0] as! UITouch
        
        let sPoint = startTouch.location(in: targetView)
        self.startPoint = targetPdfView?.convert(sPoint, to: (targetPdfView?.currentPage)!)
        
        //タップ位置に何もない時
        guard let selection : PDFSelection = (targetPdfView?.currentPage?.selectionForWord(at: startPoint)) else {
            self.undoAnnotation.append(0)
            return
        }
        
        //選択されたものに、ハイライトまたは下線を追加する
        let arraySelections = selection.selectionsByLine()
        for select : PDFSelection in arraySelections {
            addAnnotations(bounds: select.bounds(for: (targetPdfView?.currentPage)!), mode: "began", targetPdfView: targetPdfView!)
        }
    }
    
    func _touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {     //NSLog("_touchesMoved")
        let targetPdfView = self.view.viewWithTag(self.nowPage + self.kTagPdfView) as? PreviewPDFView
        let targetView = self.view.viewWithTag(self.nowPage + self.kTagCanvasStickyView) as! StickyBaseView
        
        let allTouches = (touches as NSSet).allObjects
        let touch = allTouches[0] as! UITouch
        
        let ePoint = touch.location(in: targetView)
        let cPoint = touch.location(in: targetView)
        self.endPoint = targetPdfView?.convert(ePoint, to: (targetPdfView?.currentPage)!)
        self.currentPoint = targetPdfView?.convert(cPoint, to: (targetPdfView?.currentPage)!)
        
        //タップ位置に何もない時
        guard let selection : PDFSelection = (targetPdfView?.currentPage?.selection(from: self.startPoint, to: self.currentPoint)) else {
            return
        }
        
        //選択されたものに、ハイライトまたは下線を追加する
        var arraySelections = selection.selectionsByLine()
        
        //選択されたもののboundsを取得する
        var selectionBounds : [CGRect] = []
        for i in 0 ..< arraySelections.count {
            selectionBounds.append(arraySelections[i].bounds(for: (targetPdfView?.currentPage)!))
        }
        
        //touchesBeganから前回のtouchesMovedまで追加されたAnnotationの数を取得する
        let addIndex : Int = (targetPdfView?.currentPage?.annotations.count)! - (self.undoAnnotation.last ?? 0)

        //touchesBeganから追加された場合Annotationsのboundsを取得する
        var annotationBounds : [CGRect] = []
        for i in addIndex ..< (targetPdfView?.currentPage?.annotations.count)! {
            annotationBounds.append((targetPdfView?.currentPage?.annotations[i].bounds)!)
        }
        
        //前回touchesMovedに追加したものと比べて、選択が解除されたものをページから削除する
        for i in 0 ..< self.lastSelection.count {
            if selectionBounds.contains(self.lastSelection[i]) {
                continue
            }
            if annotationBounds.contains(self.lastSelection[i]) {
                let annotationIndex = annotationBounds.firstIndex(of: self.lastSelection[i])! + addIndex
                
                //ページから削除する
                let lastAnnotation : PDFAnnotation = (targetPdfView?.currentPage?.annotations[annotationIndex])!
                targetPdfView?.currentPage?.removeAnnotation(lastAnnotation)
                annotationBounds.remove(at: annotationIndex - addIndex)
                
                let index = self.currentSelection.firstIndex(of: self.lastSelection[i])
                self.currentSelection.remove(at: index!)
                
                //追加されたAnnotation数を-1とする
                let cnt = self.undoAnnotation.last! - 1
                self.undoAnnotation.removeLast()
                self.undoAnnotation.append(cnt)
            }
        }
        self.lastSelection = self.currentSelection
        
        //前回touchesMovedに追加したものと比べて、新たに選択したものをページに追加する
        for m in 0 ..< arraySelections.count {
            if self.lastSelection.count == 0 {
                addAnnotations(bounds: selectionBounds[m], mode: "moved", targetPdfView: targetPdfView!)
            } else {
                //すでに追加したものは、何もしない
                if self.lastSelection.contains(selectionBounds[m]) {
                    continue
                }
                //ページに追加する
                addAnnotations(bounds: selectionBounds[m], mode: "moved", targetPdfView: targetPdfView!)
            }
        }
        self.lastSelection = self.currentSelection
    }
    
    func _touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {     //NSLog("_touchesEnded")
        //追加されたAnnotationの数が0の時
        self.undoAnnotation = self.undoAnnotation.filter { return $0 != 0 }
        
        //当該ページのAnnotation情報を更新する
        self.pdfPageAnnotationDict[nowPage] = self.undoAnnotation
        
        //配列をクリアする
        self.currentSelection = []
        self.lastSelection = []
    }
    
    func _touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        NSLog("_touchesCancelled")
    }
    
    //MARK: - Event Method
    /*****
     pdfを表示するScrollViewを作成する
     *****/
    func createPdfScrollView(pageNo: Int, isInitCreateThumb:Bool = false) -> DocumentScrollView {
        
        let scrollPosition = pageNo - 1
        
        let pdfScrollView = DocumentScrollView(frame: CGRect(x: CGFloat(scrollPosition) * (UIApplication.shared.keyWindow?.bounds.width)! ,
                                                             y: 0,
                                                             width: (UIApplication.shared.keyWindow?.bounds.width)!,
                                                             height: (UIApplication.shared.keyWindow?.bounds.height)!))
        
        //ズーム用のセンターViewの設定を行う
        pdfScrollView.minimumZoomScale = 1
        pdfScrollView.maximumZoomScale = 6
        pdfScrollView.delegate = self
        pdfScrollView.showsHorizontalScrollIndicator = false
        pdfScrollView.showsVerticalScrollIndicator = false
        //pdfScrollView.isScrollEnabled = false
        pdfScrollView.isMultipleTouchEnabled = true
        pdfScrollView.delaysContentTouches = false
        //pdfScrollView.canCancelContentTouches = false
        //pdfScrollView.bounces = false
        pdfScrollView.bouncesZoom = false
        pdfScrollView.decelerationRate = UIScrollViewDecelerationRateFast
        pdfScrollView.isUserInteractionEnabled = true
        
        pdfScrollView.tag = pageNo //※tag はページ番号を設定する
        pdfScrollView.backgroundColor = UIColor.lightGray
        
        //トリプルタップのイベントを追加
        let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(tripleTap(gesture:)))
        tripleTapGesture.numberOfTapsRequired = 3 //トリプルタップ
        pdfScrollView.addGestureRecognizer(tripleTapGesture)
        
        autoreleasepool{
            
            //画面表示上のPDFファイルのサイズ
            let _docContextRect = docContextRect(targetPage: pageNo)
            
            let pdfPageView = PreviewPDFView()
            pdfPageView.delegate = self
            let currentPage = docs_pdf?.page(at: pageNo - 1)!
            /*pdfPageView.frame = CGRect(x: 0,
             y: 0,
             width: (UIApplication.shared.keyWindow?.bounds.width)! / 1.0,
             height: (UIApplication.shared.keyWindow?.bounds.height)! / 1.0)*/
            pdfPageView.frame = _docContextRect
            let mediaWidth = CGFloat((currentPage?.bounds(for: .mediaBox).width)!)
            let mediaHeight = CGFloat((currentPage?.bounds(for: .mediaBox).height)!)
            let cropWidth = CGFloat((currentPage?.bounds(for: .cropBox).width)!)
            let cropHeight = CGFloat((currentPage?.bounds(for: .cropBox).height)!)
            if (mediaWidth * mediaHeight) >= (cropWidth * cropHeight) {
                pdfPageView.displayBox = .cropBox
            }else {
                pdfPageView.displayBox = .mediaBox
            }
            
            //pdfPageView.usePageViewController(true, withViewOptions: nil)
            pdfPageView.interpolationQuality = .low
            pdfPageView.displayMode = .singlePage
            pdfPageView.backgroundColor = UIColor.clear
            pdfPageView.displaysPageBreaks = false
            pdfPageView.autoScales = true
            pdfPageView.tag = pageNo + kTagPdfView //※tag はページ番号を設定する
            
            // 縦横混在PDFやページごとのサイズ違いPDFに対応するため、該当ページのみ切り出してPDFViewに与える。
            let tmpPdf = PDFDocument()
            tmpPdf.insert(currentPage!, at: 0)
            pdfPageView.document = tmpPdf
            
            //手書きメモ用のView
            let canvasImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: _docContextRect.width, height: _docContextRect.height))
            canvasImageView.isUserInteractionEnabled = true
            canvasImageView.tag = pageNo + kTagCanvasView
            pdfPageView.addSubview(canvasImageView)
            pdfScrollView.addSubview(pdfPageView)
            
            //付箋用のViewを追加
            let canvasStickyView = StickyBaseView()
            
            canvasStickyView.frame = CGRect(x: 0, y: 0, width: _docContextRect.width, height: _docContextRect.height)
            canvasStickyView.tag = kTagCanvasStickyView + pageNo
            canvasStickyView.backgroundColor = UIColor.clear
            canvasStickyView.penDelegate = self
            canvasStickyView.isUserInteractionEnabled = false
            pdfPageView.addSubview(canvasStickyView)
            
            //元に戻すボタンの活性・非活性を制御
            if (self.pdfPageAnnotationDict[nowPage] != nil) {
                if (self.pdfPageAnnotationDict[nowPage]!.count > 0) {
                    self.undoButton.isEnabled = true
                } else {
                    self.undoButton.isEnabled = false
                }
            } else {
                self.undoButton.isEnabled = false
            }
            
        }
        
        return pdfScrollView
        
    }
    
    /*****
     ScrollViewに表示するPDFViewを設定する
     再設定の対象は表示ページと前後ページ（kMaxDisplayView）のみ
     *****/
    func buildPage(isCreatePdf:Bool = false) {
        
        var startIndex = (nowPage - 1) - kMaxDisplayView - 1 //表示しないページをクリアするため前後多めにする
        if startIndex < 0 {
            startIndex = 0
        }
        var endIndex = (nowPage - 1) + kMaxDisplayView + 1  //表示しないページをクリアするため前後多めにする
        if endIndex > self.maxPages - 1 {
            endIndex = self.maxPages - 1
        }
        
        if self.maxPages == 1 {
            endIndex = 0
        }
        
        for i in startIndex...endIndex {
            
            autoreleasepool{
                
                if i >= (nowPage - 1) - kMaxDisplayView && i <= (nowPage - 1) + kMaxDisplayView {
                    //表示ページ範囲内
                    if let _ = self.pdfPageViewDict[i + 1] {
                        
                        if isCreatePdf {
                            //ページを作成する
                            self.pdfPageViewDict[i + 1] = self.createPdfScrollView(pageNo: i + 1)
                        }
                        
                    }else {
                        
                        //ページ未作成の場合は作成する
                        self.pdfPageViewDict[i + 1] = self.createPdfScrollView(pageNo: i + 1)
                    }
                    
                    if let _ = self.view.viewWithTag(i + 1){
                        
                        if isCreatePdf {
                            self.view.viewWithTag(i + 1)?.removeFromSuperview()
                            self.baseScrollView.addSubview(self.pdfPageViewDict[i + 1]!)
                        }else {
                            //addViewされている場合
                            if let _ = self.view.viewWithTag(nowPage + self.kTagCanvasView) {
                                
                            }else {
                                //pdfViewはあってもCancvasViewが存在しない場合がある
                                //その対応として本処理を追加
                                self.view.viewWithTag(i + 1)?.removeFromSuperview()
                                self.baseScrollView.addSubview(self.pdfPageViewDict[i + 1]!)
                            }
                        }
                        
                    }else {
                        self.baseScrollView.addSubview(self.pdfPageViewDict[i + 1]!)
                    }
                    
                }else {
                    
                    // ページ描画範囲外
                    if let removeView = self.view.viewWithTag(i + 1){
                        self.pdfPageViewDict.removeValue(forKey: i + 1)
                        removeView.removeFromSuperview()
                    }
                }
            }
        }
        
        self.baseScrollView.isUserInteractionEnabled = true
    }
    
    func reBuildPage() {
        
        for i in 0...maxPages - 1 {
            
            autoreleasepool{
                
                if let removeView = self.view.viewWithTag(i + 1){
                    removeView.removeFromSuperview()
                }
                
                if i >= (nowPage - 1) - kMaxDisplayView && i <= (nowPage - 1) + kMaxDisplayView {
                    
                    // 設定されている場合は一旦クリア
                    if let removeView = self.view.viewWithTag(i + 1){
                        removeView.removeFromSuperview()
                    }
                    
                    self.pdfPageViewDict[i + 1] = self.createPdfScrollView(pageNo: i + 1)
                    self.baseScrollView.addSubview(self.pdfPageViewDict[i + 1]!)
                    
                }else {
                    //    ページ描画範囲外
                    if let removeView = self.view.viewWithTag(i + 1){
                        removeView.removeFromSuperview()
                    }
                }
                
                //NSLog("!!!!!!!!!!!********************\(nowPage)")
            }
        }
        
        //NSLog("終わり********************\(nowPage)")
        
        self.baseScrollView.isUserInteractionEnabled = true
    }
    
    //トリプルタップ（ズーム戻す）
    func tripleTap(gesture: UITapGestureRecognizer) -> Void {
        
        let targetView = self.view.viewWithTag(nowPage) as! UIScrollView
        targetView.setZoomScale(1.0, animated: true)
        
    }
    
    //ズームスケールの計算
    func zoomRectForScale(scale:CGFloat, center: CGPoint) -> CGRect{
        
        var zoomRect: CGRect = CGRect()
        zoomRect.size.height = self.view.frame.size.height / scale
        zoomRect.size.width = self.view.frame.size.width / scale
        
        zoomRect.origin.x = center.x - zoomRect.size.width / 2.0
        zoomRect.origin.y = center.y - zoomRect.size.height / 2.0
        
        return zoomRect
        
    }
    
    //画面更新処理
    func reloadDisplay() {
        
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        
        if let keyWindow = UIApplication.shared.keyWindow {
            width = keyWindow.bounds.width
            height = keyWindow.bounds.height
        }
        
        baseScrollView.contentSize = CGSize(width: width * CGFloat(maxPages),
                                            height: height)
        
        //ScrollViewを格納しているDictionaryをクリア
        self.pdfPageViewDict.removeAll()
        //再作成
        self.reBuildPage()
        
        //ページスクロールの位置を設定する
        baseScrollView.contentOffset = CGPoint(x: width * CGFloat((nowPage - 1)),
                                               y: baseScrollView.contentOffset.y)
        
    }
    
    //ドキュメント自体のRectを算出する
    func docContextRect(targetPage: Int, isSpreadRect:Bool = true) -> CGRect {
        
        let _targetPage = targetPage
        //if self.isFavorite {
        //お気に入りから来た場合は指定ページ以前が削除されている分を考慮する
        //    _targetPage = _targetPage + self.startPage - 1
        //}
        
        let page: CGPDFPage? = docs?.page(at: _targetPage)
        let box: CGRect? = page?.getBoxRect(.mediaBox)
        let cropBox: CGRect? = page?.getBoxRect(.cropBox)
        let angle: Int32? = page?.rotationAngle
        
        // ・計算ができない場合は、早めに関数を抜ける。
        // ・guard構文でアンラップするのは、以降その変数を使いたいから
        guard var unwrappedBox = box else {
            return CGRect.zero
        }
        
        guard let unwrappedCropBox = cropBox else {
            return CGRect.zero
        }
        
        guard let unwrappedAngle = angle else {
            return CGRect.zero
        }
        
        let boxArea: CGFloat = unwrappedBox.size.width * unwrappedBox.size.height
        let cropBoxArea: CGFloat = unwrappedCropBox.size.width * unwrappedCropBox.size.height
        
        if boxArea >= cropBoxArea {
            unwrappedBox = unwrappedCropBox
        }
        
        var widthSize = unwrappedBox.size.width
        var heightSize = unwrappedBox.size.height
        
        if ( unwrappedAngle == 90 || unwrappedAngle == -90 || unwrappedAngle == -270 || unwrappedAngle == 270 ) {
            widthSize = unwrappedBox.size.height
            heightSize = unwrappedBox.size.width
        }
        
        guard let keyWindow = UIApplication.shared.keyWindow else {
            return CGRect.zero
        }
        
        let boundsWidth = keyWindow.bounds.width
        let boundsHeight = keyWindow.bounds.height
        
        let xScale: CGFloat = (boundsWidth / 1.0) / widthSize
        let yScale: CGFloat = (boundsHeight / 1.0) / heightSize
        let scale: CGFloat = min(xScale, yScale)
        let tx: CGFloat = ((boundsWidth  / 1.0) - widthSize * scale) / 2
        let ty: CGFloat = ((boundsHeight / 1.0) - heightSize * scale) / 2
        
        return CGRect(x: tx, y: ty, width: widthSize * scale, height: heightSize * scale)
    }
    
    //MARK: - Event ズーム関連
    
    //ピンチイン・ピンチアウト時の処理
    func imageViewToCenter(scrollView: UIScrollView) {
        
        //ズーム後のimageViewを画面サイズ内の場合は常にcenterに設定する
        if let targetZoomView = self.view.viewWithTag(nowPage + kTagPdfView) as? PreviewPDFView {
            let boundsSize = scrollView.frame
            let imageViewSize = targetZoomView.frame
            var newX = targetZoomView.frame.origin.x
            var newY = targetZoomView.frame.origin.y
            if imageViewSize.width < boundsSize.width {
                newX = (boundsSize.width - imageViewSize.width) / 2
            }else {
                newX = 0.0
            }
            if imageViewSize.height < boundsSize.height {
                newY = (boundsSize.height - imageViewSize.height) / 2
            }else {
                newY = 0.0
            }
            targetZoomView.frame = CGRect(x: newX,
                                          y: newY,
                                          width: targetZoomView.frame.width,
                                          height: targetZoomView.frame.height)
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        
        if let targetPdfView = self.view.viewWithTag(self.nowPage + self.kTagPdfView) as? PreviewPDFView {
            targetPdfView.sizeToFit()
            targetPdfView.setNeedsDisplay()
            targetPdfView.layoutIfNeeded()
        }
        
        let zoomView = self.view.viewWithTag(nowPage + kTagPdfView)
        
        return zoomView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        
        self.imageViewToCenter(scrollView: scrollView)
        
        return
        
    }
    
    var isZooming = false
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        
        if scrollView.zoomScale > 1.0 {
            self.isZooming = true
        }else {
            self.isZooming = false
        }
        //NSLog(String(describing: scrollView.zoomScale))
    }
    
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        
        //拡大状態からzoomScale1まで戻した場合はサムネイルを表示しない
        if self.isZooming {
            if scrollView.zoomScale == 1 {
                return
            }
        }
        if scrollView.zoomScale > 1.0 {
            return
        }
    }
}

//MARK: - PDFView Class

//PDF表示View
class PDFViewDisp: UIView {
    var page: CGPDFPage!
    var pageNo = 0
    var contextRect: CGRect!
    
    override func draw(_ rect: CGRect) {
        
        guard let page = page else { return }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            fatalError()
        }
        
        context.translateBy(x: 0, y: ((UIApplication.shared.keyWindow?.bounds.height)! / 1.0 ))
        context.scaleBy(x: 1.0, y: -1.0)
        
        
        var box = page.getBoxRect(.mediaBox)
        let cropBox = page.getBoxRect(.cropBox)
        
        if box.size.width * box.size.height >= cropBox.size.width * cropBox.size.height{
            box = cropBox
        }
        
        let angle = page.rotationAngle
        var widthSize = (box.size.width)
        var heightSize = (box.size.height)
        if ( angle == 90 || angle == -90 || angle == -270 || angle == 270 ) {
            widthSize = (box.size.height)
            heightSize = (box.size.width)
            
            let hScale = ((UIApplication.shared.keyWindow?.bounds.height)! / 1.0) / heightSize
            
            let radian: CGFloat = CGFloat(-angle) * (CGFloat(Double.pi) / 180.0)
            context.rotate(by: radian)
            context.translateBy(x: -(heightSize)*hScale, y: 0)
            
        }else if ( angle == 180 || angle == -180) {
            let radian: CGFloat = CGFloat(180) * (CGFloat(Double.pi) / 180.0)
            
            context.rotate(by: radian)
            
            let wScale = ((UIApplication.shared.keyWindow?.bounds.width)! / 1.0) / widthSize
            let hScale = ((UIApplication.shared.keyWindow?.bounds.height)! / 1.0) / heightSize
            
            context.translateBy(x: -widthSize*wScale, y: -heightSize*hScale)
        }
        
        let xScale = ((UIApplication.shared.keyWindow?.bounds.width)! / 1.0) / widthSize
        let yScale = ((UIApplication.shared.keyWindow?.bounds.height)! / 1.0) / heightSize
        
        let scale = min(xScale, yScale)
        
        var tx = (((UIApplication.shared.keyWindow?.bounds.width)!  / 1.0) - widthSize * scale) / 2
        var ty = (((UIApplication.shared.keyWindow?.bounds.height)! / 1.0) - heightSize * scale) / 2
        
        if box.origin.x != 0 || box.origin.y != 0 {
            //boxのx,yに値の指定がある場合は補正する
            if widthSize > heightSize {
                tx = -(box.origin.x * scale)
                ty = ty - (box.origin.y * scale)
                
            }else {
                tx = tx - (box.origin.x * scale)
                ty = -(box.origin.y * scale)
            }
        }
        
        //背景色を設定（コンテンツのサイズに合わせる）
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: tx, y: ty, width: widthSize * scale, height: heightSize * scale))
        context.saveGState()
        
        contextRect = CGRect(x: tx, y: ty, width: widthSize * scale, height: heightSize * scale)
        
        if ( angle == 90 || angle == -90 || angle == -270 || angle == 270 ) && (box.origin.x == 0 && box.origin.y == 0){
            context.translateBy(x: ty, y: tx)
        }else {
            context.translateBy(x: tx, y: ty)
        }
        
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = CGInterpolationQuality.none
        context.setRenderingIntent(CGColorRenderingIntent.defaultIntent)
        
        context.drawPDFPage(page)
        
        UIGraphicsEndImageContext()
    }
    
}

class PreviewPDFView: PDFView {
    
    var isMarkerMode = false
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isMarkerMode {
            let view = super.hitTest(point, with: event)
            return view
        }
        
        return nil
    }
    
    func LongPressGestureSetting(isEnabled: Bool) {
        if let gestureRecognizers = gestureRecognizers {
            for gestureRecognizer in gestureRecognizers where gestureRecognizer is UILongPressGestureRecognizer {
                gestureRecognizer.isEnabled = isEnabled
            }
            for gestureRecognizer in gestureRecognizers where gestureRecognizer is UIPinchGestureRecognizer {
                gestureRecognizer.isEnabled = isEnabled
            }
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            return true
            
        }
        return false
    }
    
}

//▼UIScrollViewはtouchesイベントを発火しないので、拡張する
class DocumentScrollView:UIScrollView {
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        //super.touchesBegan(touches, with: event)
        self.next?.touchesBegan(touches, with: event)
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        //super.touchesMoved(touches, with: event)
        self.next?.touchesMoved(touches, with: event)
        
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        //super.touchesEnded(touches, with: event)
        self.next?.touchesEnded(touches, with: event)
        
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //super.touchesCancelled(touches, with: event)
        self.next?.touchesCancelled(touches, with: event)
    }
}

//▼UIScrollViewはtouchesイベントを発火しないので、拡張する
class BaseScrollView:UIScrollView {
    
}


protocol penTouchDelegate: class {
    func _touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    func _touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    func _touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    func _touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
}

class StickyBaseView: UIView {
    
    weak var penDelegate: penTouchDelegate?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //NSLog("111111")
        //print(touches.count)
        penDelegate?._touchesBegan(touches, with: event)
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //NSLog("222222")
        penDelegate?._touchesMoved(touches, with: event)
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //NSLog("333333")
        penDelegate?._touchesEnded(touches, with: event)
    }
    
    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //NSLog("555555")
        //penDelegate?._touchesCancelled(touches, with: event)
        penDelegate?._touchesEnded(touches, with: event)
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        //NSLog("444444")
        //print(gestureRecognizer)
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            return true
        }else if gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) {
            return true
        }else if gestureRecognizer.isKind(of: UITapGestureRecognizer.self) {
            return true
        }
        
        return false
    }
}

//はみ出した付箋がタップ反応できるうようにPDFViewのタップ領域を広げる
extension PreviewPDFView {
    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let relativeFrame = self.bounds
        
        //拡大する値
        let expandValu: CGFloat = 600
        
        let hitTestEdgeInsets = UIEdgeInsetsMake(-expandValu, -expandValu, -expandValu, -expandValu)
        let hitFrame = UIEdgeInsetsInsetRect(relativeFrame, hitTestEdgeInsets)
        return hitFrame.contains(point)
    }
}
