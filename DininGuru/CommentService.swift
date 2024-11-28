//
//  CommentService.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/25/24.
//

import Foundation


struct FetchCommentsResponse: Codable {
   let comments: [Comment]
}

class CommentService {
   static let shared = CommentService()
   
   private init() {}
   
   // Fetch all comments for a specific venue
   func fetchComments(venueId: String, completion: @escaping ([Comment]) -> Void) {
      guard let url = URL(string: "http://127.0.0.1:8000/api/comments/\(venueId)") else {
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
            // Decode the wrapper response
            let fetchResponse = try JSONDecoder().decode(FetchCommentsResponse.self, from: data)
            completion(fetchResponse.comments)
         } catch {
            print("Error decoding comments: \(error)")
            completion([])
         }
      }.resume()
   }
   
   // Submit a new comment or update existing one for a user
   func submitOrUpdateComment(venueId: String, userId: String, text: String, completion: @escaping (Bool) -> Void) {
      guard let url = URL(string: "http://127.0.0.1:8000/api/comments") else {
         completion(false)
         return
      }
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST" // Use PUT or PATCH if updating
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let body: [String: Any] = [
         "venue_id": Int(venueId) ?? 0,
         "user_id": Int(userId) ?? 0,
         "text": text
      ]
      
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      
      URLSession.shared.dataTask(with: request) { _, response, error in
         if let error = error {
            print("Error submitting/updating comment: \(error)")
            completion(false)
            return
         }
         if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
            completion(true)
         } else {
            print("Failed to submit/update comment. Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            completion(false)
         }
      }.resume()
   }
   
   // Like a comment
   func likeComment(commentId: String, userId: String, completion: @escaping (Bool) -> Void) {
      guard let url = URL(string: "http://127.0.0.1:8000/api/comments/\(commentId)/like") else {
         completion(false)
         return
      }
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let body: [String: Any] = [
         "user_id": Int(userId) ?? 0
      ]
      
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      
      URLSession.shared.dataTask(with: request) { _, response, error in
         if let error = error {
            print("Error liking comment: \(error)")
            completion(false)
            return
         }
         if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            completion(true)
         } else {
            print("Failed to like comment. Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            completion(false)
         }
      }.resume()
   }
}
