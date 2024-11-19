//
//  ListElement.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/22/24.
//

import SwiftUI
import WebKit

// MARK: - Index
// ListElement: Represents each dining location item in the list, handles actions like opening a web view or toggling favorites
// loadImage: Downloads or fetches from cache the image for the venue and saves it for widget usage.

struct ListElement: View {
   let venue: Venue
   let venueURL: String?
   let isFavorite: Bool
   let onSelect: (URL) -> Void
   let onFavoriteToggle: (Int) -> Void
   
   @State private var showWebView = false
   @State private var selectedURL: URL? = nil
   
   @State private var image: UIImage? = nil
   @State private var isLoadingImage = false
   
   var body: some View {
      Button(action: {
         if let urlString = venueURL, let url = URL(string: urlString) {
            print("Opening URL: \(url)") // log for debugging
            onSelect(url) // call onSelect callback
         } else {
            print("Invalid URL for venue ID: \(venue.id)") // log if URL is bad
         }
      }) {
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
               // Open/Closed Label
               if isOpenNow(venue: venue) {
                  Text("OPEN")
                     .foregroundColor(Color(.systemBlue))
                     .font(.subheadline)
                     .bold()
               } else {
                  Text("CLOSED")
                     .foregroundColor(.gray)
                     .font(.subheadline)
                     .bold()
               }
               
               Text(venue.name)
                  .font(.title3)
                  .fontWeight(.regular)
               
               Text(formatDayParts(venue))
                  .foregroundColor(Color(UIColor.darkGray))
                  .font(.subheadline)
            }

            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 8)
            
            Button(action: {
               onFavoriteToggle(venue.id) // toggle favorite
            }) {
               Image(systemName: isFavorite ? "star.fill" : "star")
                  .foregroundColor(isFavorite ? .yellow : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            Image(systemName: "chevron.right") //navigation arrow
               .foregroundColor(.gray)
         }
      }
   }
   
   private func loadImage() {
      guard let imageURLString = venue.image, let imageURL = URL(string: imageURLString) else {
         return //no image available
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
            
            // try to save image for widget use
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
