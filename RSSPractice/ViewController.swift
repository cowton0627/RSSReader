//
//  ViewController.swift
//  RSSPractice
//
//  Created by Chun-Li Cheng on 2021/12/20.
//

import UIKit

enum CellState {
    case expended
    case collapsed
}

class RssCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var desLabel: UILabel! {
        didSet {
            desLabel.numberOfLines = 3
        }
    }
    
    var item: RSSItem? {
        didSet {
            titleLabel.text = item?.title
            dateLabel.text = item?.title
            desLabel.text = item?.title

        }
    }
    
}

class ViewController: UIViewController {
    @IBOutlet weak var myTableView: MyTableView!
    private var rssItems: [RSSItem]?
    private var cellStates: [CellState]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        myTableView.estimatedRowHeight = 155
//        myTableView.rowHeight = UITableView.automaticDimension
        fetchData()
        title = "財經新聞"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
//https://developer.apple.com/news/rss/news.rss
//https://www.apple.com/newsroom/rss-feed.rss
//https://news.ltn.com.tw/rss/business.xml
//https://www.ptt.cc/atom/movie.xml

    private func fetchData() {
        let feedParser = FeedParser()
        feedParser.parseFeed(url: "https://www.ptt.cc/atom/movie.xml") { rssItems in
            self.rssItems = rssItems
            self.cellStates = Array(repeating: .collapsed, count: rssItems.count)
            OperationQueue.main.addOperation {
                self.myTableView.reloadSections(IndexSet(integer: 0), with: .left)
//                self.myTableView.reloadData()

            }
        }
    }
    
    
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let rssItems = rssItems else {
            return 0
        }
        
        return rssItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "\(RssCell.self)", for: indexPath) as? RssCell else {
            return UITableViewCell()
        }
        if let item = rssItems?[indexPath.row] {
//            cell.titleLabel.text =
//            cell.desLabel.text =
//            cell.dateLabel.text =
            cell.item = item
            cell.selectionStyle = .none
            if let cellStates = cellStates {
                cell.desLabel.numberOfLines = (cellStates[indexPath.row] == .expended) ? 0 : 4
            }
        }
            
        return cell
    }
    
    
}

extension ViewController: UITableViewDelegate {
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//
//    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) as? RssCell else {
            return
        }
        tableView.beginUpdates()
        cell.desLabel.numberOfLines = (cell.desLabel.numberOfLines == 0) ? 3:0
        cellStates?[indexPath.row] = (cell.desLabel.numberOfLines == 0) ? .expended:.collapsed
        tableView.endUpdates()
//        tableView.reloadData()
    }
    
}
