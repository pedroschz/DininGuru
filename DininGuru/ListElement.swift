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
   
   @State private var showWebView = false
   @State private var selectedURL: URL? = nil
   
   @State private var image: UIImage? = nil
   @State private var isLoadingImage = false
   let reviewCount: Int?

   private var averageColor: Color {
      guard let avg = venue.averageRating else { return .gray }
      if avg >= 0.25 {
         return .green
      } else if avg <= -0.25 {
         return .red
      } else {
         return .gray
      }
   }
   
   
   var body: some View {
      HStack(spacing: 12) {
         Group {
            if let image = image {
               Image(uiImage: image)
                  .resizable()
                  .aspectRatio(3 / 2, contentMode: .fill)
                  .frame(width: 100, height: 70)
                  .cornerRadius(10)
                  .clipped()
                  .grayscale(isClosedNow() ? 1 : 0)
            } else {
               ZStack {
                  Rectangle()
                     .foregroundColor(Color(.systemGray5))
                     .frame(width: 100, height: 70)
                     .cornerRadius(10)
                  
                  if isLoadingImage {
                     ProgressView()
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
            loadImage()
         }
         
         VStack(alignment: .leading, spacing: 4) {
            Text(venue.name)
               .font(.title3)
               .fontWeight(.regular)
               .foregroundColor(isClosedNow() ? .gray : .primary)
            
            if let closingTime = getClosingTime(venue: venue) {
               Text("Open until \(closingTime)")
                  .foregroundColor(isClosedNow() ? .gray : Color(UIColor.darkGray))
                  .font(.subheadline)
            } else {
               Text("CLOSED")
                  .foregroundColor(.gray)
                  .font(.subheadline)
                  .bold()
            }
            
            // Average Rating
            if let averageRating = venue.averageRating, let reviewCount = reviewCount {
               HStack{
                  HStack(spacing: 3) {
                     Image(systemName: averageRating >= 0 ? "chevron.up" : "chevron.down")
                        .foregroundColor(averageColor)
                        .imageScale(.small)
                     Text("\(String(format: "%.0f", abs(averageRating * 100)))%")
                        .font(.subheadline)
                        .foregroundColor(averageColor)
                  }
                  .font(.subheadline)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .bold()
                  .background(
                     RoundedRectangle(cornerRadius: 8).fill(averageColor.opacity(0.2))
                  )
                  
                  HStack (spacing: 3){
                     Image(systemName: "person.3.fill").foregroundColor(.gray).imageScale(.small)


                     Text("\(reviewCount)")
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                  }
               }
               
            } else {
               Text("Loading reviews...")
                  .font(.subheadline)
                  .foregroundColor(.gray)
            }
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.trailing, 8)
      }
   }
   
   private func isClosedNow() -> Bool {
      return getClosingTime(venue: venue) == nil
   }
   
   private func loadImage() {
      guard let imageURLString = venue.image, let imageURL = URL(string: imageURLString) else {
         return
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
            
            // Save for widget
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
                  print("Error saving image: \(error.localizedDescription)")
               }
            } else {
               print("Shared container URL is nil.")
            }
         } else {
            print("Failed to load image for \(venue.name): \(error?.localizedDescription ?? "Unknown error")")
            DispatchQueue.main.async {
               self.isLoadingImage = false
            }
         }
      }.resume()
   }
}


func getClosingTime(venue: Venue) -> String? {
   let now = Date()
   let formatter = DateFormatter()
   formatter.dateFormat = "yyyy-MM-dd"
   formatter.timeZone = TimeZone.current
   
   let todayString = formatter.string(from: now)
   
   guard let today = venue.days.first(where: { $0.date == todayString }) else {
      return nil
   }
   
   if today.status.lowercased() != "open" {
      return nil
   }
   
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

