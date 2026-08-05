//
//  RSSItem.swift
//  RSSReader
//
//  Created by Chun-Li Cheng on 2021/12/20.
//

import Foundation

struct RSSItem: Codable {
    let title: String
    let pubDate: String
    let description: String
    let link: String
    let imageURL: String?
    let sourceTitle: String
}

struct FeedSubscription: Codable, Equatable {
    var title: String
    let url: String
}

struct FeedCategory: Codable, Equatable {
    var title: String
    var subscriptions: [FeedSubscription]
}

enum FeedSelection: Equatable {
    case all
    case category(Int)
    case subscription(categoryIndex: Int, subscriptionIndex: Int)
}

enum FeedParserError: Error {
    case invalidURL
    case emptyResponse
}

class FeedParser: NSObject, XMLParserDelegate {
    private var rssItems = [RSSItem]()
    private var currentElement = ""
    private var isInsideItem = false

    private var requestedSourceTitle = ""
    private var currentFeedTitle = "" {
        didSet {
            currentFeedTitle = currentFeedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    private var currentTitle = "" {
        didSet {
            currentTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    private var currentPubDate = "" {
        didSet {
            currentPubDate = currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    private var currentDescription = "" {
        didSet {
            currentDescription = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    private var currentLink = "" {
        didSet {
            currentLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    private var currentImageURL: String?
    private var feedURL: URL?

    private var parserCompletionHandler: ((Result<[RSSItem], Error>) -> Void)?

    func parseFeed(url: String, sourceTitle: String? = nil, completionHandler: ((Result<[RSSItem], Error>) -> Void)?) {
        rssItems = []
        currentElement = ""
        isInsideItem = false
        requestedSourceTitle = sourceTitle ?? URL(string: url)?.host ?? url
        currentFeedTitle = ""
        parserCompletionHandler = completionHandler

        guard let url = URL(string: url), ["http", "https"].contains(url.scheme?.lowercased()) else {
            completionHandler?(.failure(FeedParserError.invalidURL))
            return
        }

        feedURL = url

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completionHandler?(.failure(error))
                return
            }

            guard let data = data, !data.isEmpty else {
                completionHandler?(.failure(FeedParserError.emptyResponse))
                return
            }

            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }.resume()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "item" || elementName == "entry" {
            isInsideItem = true
            currentTitle = ""
            currentPubDate = ""
            currentDescription = ""
            currentLink = ""
            currentImageURL = nil
        }

        if isInsideItem, currentImageURL == nil, let imageURL = imageURL(from: elementName, qualifiedName: qName, attributes: attributeDict) {
            currentImageURL = imageURL
        }

        if isInsideItem, elementName == "link", currentLink.isEmpty {
            currentLink = articleLink(from: attributeDict) ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title":
            if isInsideItem {
                currentTitle += string
            } else {
                currentFeedTitle += string
            }
        case "pubDate", "published", "updated":
            currentPubDate += string
        case "description", "summary", "content":
            currentDescription += string
        case "link":
            if isInsideItem {
                currentLink += string
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let rssItem = RSSItem(
                title: currentTitle,
                pubDate: currentPubDate,
                description: currentDescription.strippingHTML(),
                link: currentLink,
                imageURL: currentImageURL ?? currentDescription.firstImageURL(relativeTo: feedURL),
                sourceTitle: currentFeedTitle.isEmpty ? requestedSourceTitle : currentFeedTitle
            )
            rssItems.append(rssItem)
            isInsideItem = false
        }
    }


    private func imageURL(from elementName: String, qualifiedName: String?, attributes: [String: String]) -> String? {
        let name = (qualifiedName ?? elementName).lowercased()
        let lowercasedAttributes = attributes.reduce(into: [String: String]()) { result, entry in
            result[entry.key.lowercased()] = entry.value
        }

        let isImageElement = [
            "enclosure",
            "media:content",
            "media:thumbnail",
            "thumbnail",
            "itunes:image",
            "image"
        ].contains(name)

        let type = lowercasedAttributes["type"]?.lowercased() ?? ""
        let medium = lowercasedAttributes["medium"]?.lowercased() ?? ""
        let candidate = lowercasedAttributes["url"] ?? lowercasedAttributes["href"] ?? lowercasedAttributes["src"]

        guard isImageElement, let candidate else { return nil }

        if name == "enclosure", !type.hasPrefix("image/"), !candidate.looksLikeImageURL {
            return nil
        }

        if name == "media:content", !type.hasPrefix("image/"), medium != "image", !candidate.looksLikeImageURL {
            return nil
        }

        return candidate.absoluteURLString(relativeTo: feedURL)
    }

    private func articleLink(from attributes: [String: String]) -> String? {
        let lowercasedAttributes = attributes.reduce(into: [String: String]()) { result, entry in
            result[entry.key.lowercased()] = entry.value
        }

        let rel = lowercasedAttributes["rel"]?.lowercased()
        guard rel == nil || rel == "alternate" else { return nil }
        return lowercasedAttributes["href"]?.absoluteURLString(relativeTo: feedURL)
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        parserCompletionHandler?(.success(rssItems))
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserCompletionHandler?(.failure(parseError))
    }
}

private extension String {
    func strippingHTML() -> String {
        guard let data = data(using: .utf8),
              let attributedString = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return self
        }

        return attributedString.string
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func firstImageURL(relativeTo baseURL: URL?) -> String? {
        let attributes = ["src", "data-src", "data-original", "data-lazy-src"]
        for attribute in attributes {
            let pattern = #"<img[^>]+"# + attribute + #"=["']([^"']+)["']"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
                  let range = Range(match.range(at: 1), in: self) else {
                continue
            }

            return String(self[range]).absoluteURLString(relativeTo: baseURL)
        }

        return nil
    }

    var looksLikeImageURL: Bool {
        let lowercased = lowercased()
        return [".jpg", ".jpeg", ".png", ".webp", ".gif", ".heic"].contains { lowercased.contains($0) }
    }

    func absoluteURLString(relativeTo baseURL: URL?) -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")

        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }

        if let baseURL, let url = URL(string: trimmed, relativeTo: baseURL) {
            return url.absoluteURL.absoluteString
        }

        return nil
    }
}
