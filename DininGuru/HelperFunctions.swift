//
//  HelperFunctions.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/22/24.
//

import Foundation
import SwiftUI
import WebKit
import Network

// MARK: - Index
// Venue: Represents a dining venue with name, address and open status
// formatTime: Converts time to a human-readable format
// todayDateString: Returns today's date
// formatDayParts: formats the open and close times
// isOpenNow: Checks if a venue is currently open
// ImageCache: singleton class for caching images.
// WebView: wrapper for displaying web content within SwiftUI views
// NetworkMonitor: Monitors network connectivity status

struct Venue: Identifiable, Codable {
   var id: Int
   var name: String
   var address: String
   var image: String?
   var imageData: Data?
   var days: [Day]
   
   // nested struct for a day
   struct Day: Codable, Hashable, Equatable {
      var date: String
      var status: String
      var dayparts: [DayPart]
   }
   
   // nested struct for day part
   struct DayPart: Codable, Hashable, Equatable {
      var starttime: String
      var endtime: String
      var label: String
   }
   
   var isOpen: Bool {
      days.contains(where: { $0.status == "open" })
   }
}

func formatTime(_ timeString: String) -> String {
   let formatter = DateFormatter()
   formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
   formatter.locale = Locale(identifier: "en_US_POSIX")
   
   if let date = formatter.date(from: timeString) {
      let outputFormatter = DateFormatter()
      outputFormatter.dateFormat = "h:mm a"
      outputFormatter.amSymbol = "a"
      outputFormatter.pmSymbol = "p"
      outputFormatter.locale = Locale(identifier: "en_US_POSIX")
      outputFormatter.timeZone = TimeZone.current
      
      let timeString = outputFormatter.string(from: date).lowercased()
      return timeString.replacingOccurrences(of: ":00", with: "").replacingOccurrences(of: " ", with: "")
   } else {
      return "Invalid time format"
   }
}

func todayDateString() -> String {
   let formatter = DateFormatter()
   formatter.dateFormat = "yyyy-MM-dd"
   return formatter.string(from: Date())
}


func formatDayParts(_ venue: Venue) -> String {
   let dateFormatter = DateFormatter()
   dateFormatter.dateFormat = "yyyy-MM-dd"
   let todayDateString = dateFormatter.string(from: Date())
   
   guard let day = venue.days.first(where: { $0.date == todayDateString }) else {
      return "CLOSED TODAY"
   }
   
   return formatDayParts(day.dayparts)
}

func formatDayParts(_ dayparts: [Venue.DayPart]) -> String {
   if dayparts.isEmpty {
      return "CLOSED TODAY"
   }
   
   if dayparts.count == 1 {
      let start = formatTime(dayparts[0].starttime)
      let end = formatTime(dayparts[0].endtime)
      return "\(start)-\(end)"
   }
   
   let formattedTimes = dayparts.map { daypart in
      let start = formatTime(daypart.starttime).dropLast()
      let end = formatTime(daypart.endtime).dropLast()
      return "\(start) - \(end)"
   }
   
   return formattedTimes.joined(separator: " | ")
}



func isOpenNow(venue: Venue) -> Bool {
   let now = Date()
   let formatter = DateFormatter()
   formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
   formatter.locale = Locale(identifier: "en_US_POSIX")
   
   let dateFormatter = DateFormatter()
   dateFormatter.dateFormat = "yyyy-MM-dd"
   let todayDateString = dateFormatter.string(from: now)
   
   guard let day = venue.days.first(where: { $0.date == todayDateString }) else {
      return false // no data for today
   }
   
   for daypart in day.dayparts {
      if let start = formatter.date(from: daypart.starttime), let end = formatter.date(from: daypart.endtime) {
         if now >= start && now <= end {
            return true
         }
      }
   }
   return false
}

class ImageCache {
   static let shared = ImageCache() // singleton instance
   
   private init() {}
   
   private let cache = NSCache<NSString, UIImage>() // cache for storing images
   
   // fetch image from cache
   func getImage(forKey key: String) -> UIImage? {
      cache.object(forKey: key as NSString)
   }
   
   // store image in cache
   func setImage(_ image: UIImage, forKey key: String) {
      cache.setObject(image, forKey: key as NSString)
   }
}

struct WebView: UIViewRepresentable {
   let url: URL
   @Binding var isLoading: Bool
   
   func makeCoordinator() -> Coordinator {
      Coordinator(self)
   }
   
   func makeUIView(context: Context) -> WKWebView {
      let webView = WKWebView()
      webView.navigationDelegate = context.coordinator
      return webView
   }
   
   func updateUIView(_ uiView: WKWebView, context: Context) {
      if uiView.url != url {
         let request = URLRequest(url: url)
         uiView.load(request)
      }
   }
   
   // MARK: coordinator for handling navigation
   class Coordinator: NSObject, WKNavigationDelegate {
      var parent: WebView
      
      init(_ parent: WebView) {
         self.parent = parent
      }
      
      func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
         parent.isLoading = true
      }
      
      func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
         parent.isLoading = false
      }
      
      func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
         parent.isLoading = false
         // TODO: Add error handling logic for web view loading failure
      }
      
      func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
         parent.isLoading = false
         // MARK: maybe more user-friendly error message
      }
   }
}

class NetworkMonitor: ObservableObject {
   private let monitor = NWPathMonitor()
   private let queue = DispatchQueue(label: "NetworkMonitor")
   
   @Published var isConnected = true
   
   init() {
      monitor.pathUpdateHandler = { path in
         DispatchQueue.main.async {
            self.isConnected = path.status == .satisfied
         }
      }
      monitor.start(queue: queue)
   }
   
   deinit {
      monitor.cancel()
   }
}
