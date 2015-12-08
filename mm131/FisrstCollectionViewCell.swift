//
//  FisrstCollectionViewCell.swift
//  mm131
//
//  Created by lu on 15/12/5.
//  Copyright © 2015年 lu. All rights reserved.
//

import UIKit
import YYWebImage

class FisrstCollectionViewCell: UICollectionViewCell {
    //image是直接连接到storyboard上的
    var imageView = YYAnimatedImageView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
        imageView.frame = bounds
        imageView.contentMode = UIViewContentMode.ScaleAspectFit
    }
}
