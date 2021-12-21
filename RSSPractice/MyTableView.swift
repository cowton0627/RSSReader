//
//  MyTableView.swift
//  RSSPractice
//
//  Created by Chun-Li Cheng on 2021/12/21.
//

import UIKit

// 自適應高度tableView
class MyTableView: UITableView {

    override var contentSize:CGSize {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }

}
