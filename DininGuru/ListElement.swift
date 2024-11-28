//
//  ListElement.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/22/24.
//

import SwiftUI
import WebKit

// MARK: - Index
// ListElement: Represents each dining location item in the list, handles actions like opening a web view
// loadImage: Downloads or fetches from cache the image for the venue and saves it for widget usage.

struct ListElement: View {
   let venue: Venue
   let venueURL: String?
   // let onSelect: (URL) -> Void
   
   @State private var showWebView = false
   @State private var selectedURL: URL? = nil
   
   @State private var image: UIImage? = nil
   @State private var isLoadingImage = false
   
   var body: some View {
      /*Button(action: {
       if let urlString = venueURL, let url = URL(string: urlString) {
       print("Opening URL: \(url)") // log for debugging
       onSelect(url) // call onSelect callback
       } else {
       print("Invalid URL for venue ID: \(venue.id)") // log if URL is bad
       }
       })*/
      HStack(spacing: 12) {
         Group {
            if let image = image { // check if image is loaded
               Image(uiImage: image)
                  .resizable()
                  .aspectRatio(3 / 2, contentMode: .fill)
                  .frame(width: 100, height: 70)
                  .cornerRadius(10)
                  .clipped()
            } else {
               ZStack {
                  Rectangle() // placeholder for image
                     .foregroundColor(Color(.systemGray5))
                     .frame(width: 100, height: 70)
                     .cornerRadius(10)
                  
                  if isLoadingImage {
                     ProgressView() // loading indicator
                  } else {
                     Image(systemName: "building.2.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                  }
               }
            }
         }
         .onAppear {
            loadImage() // load image when view appears
         }
         
         VStack(alignment: .leading, spacing: 4) {
            Text(venue.name)
               .font(.title3)
               .fontWeight(.regular)
            
            if let closingTime = getClosingTime(venue: venue) {
               Text("Open until \(closingTime)")
                  .foregroundColor(Color(UIColor.darkGray))
                  .font(.subheadline)
            } else {
               Text("CLOSED")
                  .foregroundColor(.gray)
                  .font(.subheadline)
                  .bold()
            }
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.trailing, 8)
         
         
      }
      
   }
   
   private func loadImage() {
      guard let imageURLString = venue.image, let imageURL = URL(string: imageURLString) else {
         return // no image available
      }
      
      if let cachedImage = ImageCache.shared.getImage(forKey: imageURLString) {
         self.image = cachedImage
         return
      }
      
      isLoadingImage = true
      URLSession.shared.dataTask(with: imageURL) { data, response, error in
         if let data = data, let downloadedImage = UIImage(data: data) {
            ImageCache.shared.setImage(downloadedImage, forKey: imageURLString)
            DispatchQueue.main.async {
               self.image = downloadedImage
               self.isLoadingImage = false
            }
            
            // Try to save image for widget use
            if let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.petrvskystudios.DiningApp") {
               let imagesURL = sharedContainerURL.appendingPathComponent("Images")
               do {
                  try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true, attributes: nil)
                  let imageFileURL = imagesURL.appendingPathComponent("\(venue.id).png")
                  if let imageData = downloadedImage.pngData() {
                     try imageData.write(to: imageFileURL)
                     print("Image saved to shared container at: \(imageFileURL.path)")
                  }
               } catch {
                  print("Error saving image to shared container: \(error.localizedDescription)")
                  // TODO: proper error handling
               }
            } else {
               print("Shared container URL is nil.")
               // MARK: fallback if shared container fails
            }
         } else {
            print("Failed to load image for venue: \(venue.name), error: \(error?.localizedDescription ?? "Unknown error")")
            DispatchQueue.main.async {
               self.isLoadingImage = false
            }
            // TODO: show a default image or retry loading?
         }
      }.resume()
   }
}


func getClosingTime(venue: Venue) -> String? {
   let now = Date()
   let calendar = Calendar.current
   let dateFormatter = DateFormatter()
   dateFormatter.dateFormat = "yyyy-MM-dd"
   dateFormatter.timeZone = TimeZone.current
   
   // Get today's date as a string
   let todayString = dateFormatter.string(from: now)
   
   // Find the Day object for today
   guard let today = venue.days.first(where: { $0.date == todayString }) else {
      // No data for today
      return nil
   }
   
   // Check if the venue is open today
   if today.status.lowercased() != "open" {
      return nil // Venue is closed today
   }
   
   /*
    // Time formatter for start and end times
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mm a"
    timeFormatter.locale = Locale(identifier: "en_US_POSIX")
    timeFormatter.timeZone = TimeZone.current
    */
   
   // Iterate through today's dayparts to find current operating hours
   for dayPart in today.dayparts {
      guard let startTime = parseTime(dayPart.starttime, onDate: now),
            let endTime = parseTime(dayPart.endtime, onDate: now) else {
         continue
      }
      
      if startTime <= now && now <= endTime {
         let displayFormatter = DateFormatter()
         displayFormatter.timeStyle = .short
         displayFormatter.timeZone = TimeZone.current
         return displayFormatter.string(from: endTime)
      }
   }
   
   // Venue is closed now
   return nil
}


func parseTime(_ timeString: String, onDate date: Date) -> Date? {
   let formatter = DateFormatter()
   formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
   formatter.locale = Locale(identifier: "en_US_POSIX")
   formatter.timeZone = TimeZone.current
   
   /*
    // Parse the time string
    if let time = formatter.date(from: timeString) {
    // Combine with the provided date
    let calendar = Calendar.current
    let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
    
    var combinedComponents = DateComponents()
    combinedComponents.year = dateComponents.year
    combinedComponents.month = dateComponents.month
    combinedComponents.day = dateComponents.day
    combinedComponents.hour = timeComponents.hour
    combinedComponents.minute = timeComponents.minute
    combinedComponents.second = timeComponents.second
    
    return calendar.date(from: combinedComponents)
    }*/
   
   return formatter.date(from: timeString)
}

