//
//  VenueDetailView.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/23/24.
//

import SwiftUI
import WebKit


struct VenueDetailView: View {
   let venue: Venue
   let venueURL: String?
   @AppStorage("userId") var userId: Int?


   @State private var image: UIImage? = nil
   @State private var isLoadingImage = false
   
   // State variables for web view and alerts
   @State private var selectedURL: URL? = nil // URL selected for web view
   @State private var isWebViewLoading = false // Is web view loading
   @State private var showAlert = false // Show alert for errors
   @State private var alertMessage = "" // Message for the alert
   
   @ObservedObject private var networkMonitor = NetworkMonitor() // Monitors network status
   @State private var selectedRating: VenueRating = .neutral
   
   @State private var averageRating: Double? = nil
   @State private var showSuccessMessage = false
   @State private var showErrorMessage = false
   
   // Comment-related state variables
   @State private var comments: [Comment] = []
   @State private var newCommentText: String = ""
   @State private var isSubmittingComment = false
   
   
   var body: some View {
      
      ScrollView {
         VStack {
            VenueImage(image: image)
            VenueDetails(venue: venue, selectedRating: $selectedRating, submitUserRating: submitUserRating,                     averageRating: averageRating)
            CommentsSection(
               comments: comments,
               newCommentText: $newCommentText,
               isSubmittingComment: isSubmittingComment,
               submitOrUpdateComment: submitOrUpdateComment,
               likeComment: likeComment
            )
            WebsiteButton(showAlert: $showAlert, alertMessage: alertMessage, handleVisitWebsite: handleVisitWebsite)
         }
      }
      .navigationTitle(venue.name)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
         print("VenueDetailView appeared. UserId is: \(String(describing: userId))")
         loadImage()
         fetchAverageRating()
         fetchComments(venueId: String(venue.id)) { fetchedComments in
            DispatchQueue.main.async {
               self.comments = fetchedComments
            }
         }
      }
      .alert(isPresented: $showSuccessMessage) {
         Alert(
            title: Text("Thank You!"),
            message: Text("Your rating has been submitted."),
            dismissButton: .default(Text("OK"))
         )
      }
      .alert(isPresented: $showErrorMessage) {
         Alert(
            title: Text("Error"),
            message: Text("Failed to submit rating. Please try again later."),
            dismissButton: .default(Text("OK"))
         )
      }
      .sheet(item: $selectedURL) { url in
         WebView(url: url, isLoading: $isWebViewLoading)
            .overlay(Group {
               if isWebViewLoading {
                  ProgressView()
                     .progressViewStyle(CircularProgressViewStyle())
                     .scaleEffect(2)
               }
            })
            .edgesIgnoringSafeArea(.all)
      }
   }
   
   // MARK: - Rating Functions
   

   func submitUserRating() {
      let mealPeriod = getCurrentMealPeriod()
      
      print("Attempting to submit rating. UserId is: \(String(describing: userId))")
      
      guard let userId = userId else {
         print("User ID is nil. Cannot submit rating.")
         // Handle the case where userId is nil (user not logged in)
         showErrorMessage = true
         alertMessage = "Please log in to submit a rating."
         return
      }
      
      print("User ID unwrapped: \(userId)")
       
       RatingService.shared.submitRating(
         venueId: String(venue.id),
         rating: selectedRating.rawValue,
         userId: String(userId),
         mealPeriod: mealPeriod
       ) { success in
         DispatchQueue.main.async {
            if success {
               showSuccessMessage = true
               fetchAverageRating() // Refresh average rating
            } else {
               showErrorMessage = true
            }
         }
      }
   }
   
    func fetchAverageRating() {
       RatingService.shared.fetchAverageRating(venueId: String(venue.id)) { avgRating in
         DispatchQueue.main.async {
            self.averageRating = avgRating
         }
      }
   }

   
   // MARK: - Comment Functions
   
   func fetchComments(venueId: String, completion: @escaping ([Comment]) -> Void) {
      let mealPeriod = getCurrentMealPeriod()
      let userId = "1" // Replace with actual user ID logic
      
      var urlComponents = URLComponents(string: "http://127.0.0.1:8000/api/comments/\(venueId)")!
      urlComponents.queryItems = [
         URLQueryItem(name: "meal_period", value: mealPeriod),
         URLQueryItem(name: "user_id", value: userId)
      ]
      
      guard let url = urlComponents.url else {
         completion([])
         return
      }
      
      URLSession.shared.dataTask(with: url) { data, response, error in
         if let error = error {
            print("Error fetching comments: \(error)")
            completion([])
            return
         }
         guard let data = data else {
            print("No data received while fetching comments.")
            completion([])
            return
         }
         do {
            let fetchResponse = try JSONDecoder().decode(FetchCommentsResponse.self, from: data)
            completion(fetchResponse.comments)
         } catch {
            print("Error decoding comments: \(error)")
            completion([])
         }
      }.resume()
   }
   
   func getCurrentMealPeriod() -> String {
      let now = Date()
      let calendar = Calendar.current
      let hour = calendar.component(.hour, from: now)
      
      switch hour {
      case 6..<11:
         return "breakfast"
      case 11..<17:
         return "lunch"
      case 17..<22:
         return "dinner"
      default:
         return "closed"
      }
   }

   
    func submitOrUpdateComment() {
      let trimmedComment = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedComment.isEmpty else { return }
      
      isSubmittingComment = true
      
       guard let userId = userId else {
          // Handle the case where userId is nil (user not logged in)
          // For example, show an alert or navigate to the login screen
          showErrorMessage = true
          alertMessage = "Please log in to submit a rating."
          return
       }
       
      CommentService.shared.submitOrUpdateComment(venueId: String(venue.id), userId: String(userId), text: trimmedComment) { success in
         DispatchQueue.main.async {
            isSubmittingComment = false
            if success {
               newCommentText = ""
               fetchComments(venueId: String(venue.id)) { fetchedComments in
                  DispatchQueue.main.async {
                     self.comments = fetchedComments
                  }
               }
            } else {
               alertMessage = "Failed to submit comment. Please try again later."
               showAlert = true
            }
         }
      }
   }
   
    func likeComment(_ comment: Comment) {
       guard let userId = userId else {
          // Handle the case where userId is nil (user not logged in)
          // For example, show an alert or navigate to the login screen
          showErrorMessage = true
          alertMessage = "Please log in to submit a rating."
          return
       }
      CommentService.shared.likeComment(commentId: String(comment.id), userId: String(userId)) { success in
         if success {
            DispatchQueue.main.async {
               // Update the local like count and like state
               if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                  comments[index].like_count += 1
                  comments[index].has_liked = true
               }
            }
         } else {
            DispatchQueue.main.async {
               alertMessage = "Failed to like the comment. Please try again."
               showAlert = true
            }
         }
      }
   }
   
   // MARK: - Image Loading
   
   private func loadImage() {
      guard let imageURLString = venue.image, let imageURL = URL(string: imageURLString) else {
         return // No image available
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
         } else {
            DispatchQueue.main.async {
               self.isLoadingImage = false
            }
         }
      }.resume()
   }
   
   // MARK: - Website Handling
   
   private func handleVisitWebsite() {
      if networkMonitor.isConnected {
         if let urlString = venueURL, let url = URL(string: urlString) {
            selectedURL = url
         } else {
            alertMessage = "Invalid URL for this venue."
            showAlert = true
         }
      } else {
         alertMessage = "No network connection found."
         showAlert = true
      }
   }
   
   // MARK: - Helper Functions
   
   /*private func getClosingTime(venue: Venue) -> String? {
    // Implement your logic to get the closing time
    return venue.closingTime
    }*/
}

// Extension to make URL conform to Identifiable
extension URL: @retroactive Identifiable {
   public var id: String { absoluteString }
}

// Enum for Venue Ratings
enum VenueRating: Int, CaseIterable, Identifiable {
   case wayWorse = 1
   case worse
   case neutral
   case better
   case wayBetter
   
   var id: Int { rawValue }
}

// RadioButton View
struct RadioButton: View {
   let isSelected: Bool
   let action: () -> Void
   
   var body: some View {
      Button(action: {
         self.action()
      }) {
         Circle()
            .stroke(Color.primary, lineWidth: 2)
            .background(
               Circle()
                  .fill(isSelected ? Color.primary : Color.clear)
            )
            .frame(width: 24, height: 24)
      }
      .buttonStyle(PlainButtonStyle())
   }
}



struct VenueImage: View {
   let image: UIImage?
   
   var body: some View {
      if let image = image {
         Image(uiImage: image)
            .resizable()
            .aspectRatio(3 / 2, contentMode: .fill)
            .frame(height: 200)
            .clipped()
      } else {
         Rectangle()
            .foregroundColor(Color(.systemGray5))
            .frame(height: 200)
      }
   }
}

struct VenueDetails: View {
   let venue: Venue
   @Binding var selectedRating: VenueRating
   let submitUserRating: () -> Void
   let averageRating: Double? // Accept averageRating
   
   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         Text(venue.name)
            .font(.largeTitle)
            .padding(.top)
         // Closing time logic
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
         // Rating logic
         RatingView(selectedRating: $selectedRating, submitUserRating: submitUserRating, averageRating: averageRating)
         Divider().padding(.vertical, 16)
      }
      .padding(.horizontal)
   }
}




struct CommentsSection: View {
   let comments: [Comment]
   @Binding var newCommentText: String
   let isSubmittingComment: Bool
   let submitOrUpdateComment: () -> Void
   let likeComment: (Comment) -> Void
   
   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         Text("Comments:")
            .font(.headline)
         
         if comments.isEmpty {
            Text("No comments yet. Be the first to comment!")
               .foregroundColor(.gray)
               .padding(.vertical, 8)
         } else {
            ForEach(comments) { comment in
               CommentView(comment: comment, likeComment: likeComment)
            }
         }
         
         // Add/Update Comment
         VStack(alignment: .leading, spacing: 8) {
            Text("Add a Comment:")
               .font(.headline)
            
            TextEditor(text: $newCommentText)
               .frame(height: 100)
               .overlay(
                  RoundedRectangle(cornerRadius: 8)
                     .stroke(Color.gray.opacity(0.5), lineWidth: 1)
               )
               .padding(.bottom, 4)
            
            Button(action: submitOrUpdateComment) {
               if isSubmittingComment {
                  ProgressView()
               } else {
                  Text("Submit Comment")
                     .foregroundColor(.white)
                     .padding()
                     .frame(maxWidth: .infinity)
                     .background(Color.blue)
                     .cornerRadius(8)
               }
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment)
         }
         .padding(.top, 16)
      }
      .padding(.horizontal)
   }
}




struct WebsiteButton: View {
   @Binding var showAlert: Bool
   let alertMessage: String
   let handleVisitWebsite: () -> Void
   
   var body: some View {
      Button(action: handleVisitWebsite) {
         Text("Visit Website")
            .foregroundColor(.blue)
      }
      .padding()
      .alert(isPresented: $showAlert) {
         Alert(
            title: Text("Network Error"),
            message: Text(alertMessage),
            dismissButton: .default(Text("OK"))
         )
      }
   }
}


struct CommentView: View {
   let comment: Comment
   let likeComment: (Comment) -> Void
   
   var body: some View {
      HStack(alignment: .top) {
         Text(comment.text)
            .font(.body)
            .padding(.vertical, 4)
         
         Spacer()
         
         HStack {
            Text("\(comment.like_count)")
               .font(.subheadline)
               .foregroundColor(.gray)
            
            Button(action: { likeComment(comment) }) {
               Image(systemName: comment.has_liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                  .foregroundColor(comment.has_liked ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
         }
      }
      .padding(.vertical, 4)
   }
}


struct RatingView: View {
   @Binding var selectedRating: VenueRating
   let submitUserRating: () -> Void
   let averageRating: Double? // Accept averageRating
   
   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         Text("Rate Your Experience:")
            .font(.headline)
            .padding(.top, 16)
         
         HStack(spacing: 24) {
            ForEach(VenueRating.allCases, id: \.self) { rating in
               RadioButton(isSelected: selectedRating == rating) {
                  selectedRating = rating
               }
            }
         }
         .padding(.vertical, 8)
         
         HStack {
            Text("Way Worse Than Usual")
               .font(.subheadline)
               .foregroundColor(.gray)
            Spacer()
            Text("Way Better Than Usual")
               .font(.subheadline)
               .foregroundColor(.gray)
         }
         
         
         if let averageRating = averageRating {
            Text("Average Rating: \(String(format: "%.2f", averageRating))")
               .font(.subheadline)
               .padding(.top, 8)
         } else {
            Text("Average Rating: Loading...")
               .font(.subheadline)
               .padding(.top, 8)
         }
         
         Button("Submit Rating") {
            submitUserRating()
         }
         .padding(.top)
      }
   }
}
