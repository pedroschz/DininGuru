//
//  RatingService.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/24/24.
//

import Foundation

class RatingService {
   static let shared = RatingService()
   
   func submitRating(venueId: String, rating: VenueRating, completion: @escaping (Bool) -> Void) {
      guard let url = URL(string: "http://127.0.0.1:8000/api/ratings") else { return }
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let body: [String: Any] = [
         "venue_id": venueId,
         "user_id": "1", // Replace with actual user ID logic
         "rating": ratingToValue(rating)
      ]
      
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      
      URLSession.shared.dataTask(with: request) { _, response, error in
         if let error = error {
            print("Error submitting rating: \(error)")
            completion(false)
            return
         }
         if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
            completion(true)
         } else {
            completion(false)
         }
      }.resume()
   }
   
   func fetchAverageRating(venueId: String, completion: @escaping (Double?) -> Void) {
      guard let url = URL(string: "http://127.0.0.1:8000/api/ratings/\(venueId)/average") else { return }
      
      URLSession.shared.dataTask(with: url) { data, response, error in
         if let error = error {
            print("Error fetching average rating: \(error)")
            completion(nil)
            return
         }
         guard let data = data, let result = try? JSONDecoder().decode(AverageRatingResponse.self, from: data) else {
            completion(nil)
            return
         }
         completion(result.averageRating)
      }.resume()
   }
   
   
   private func ratingToValue(_ rating: VenueRating) -> Double {
      switch rating {
      case .wayWorse: return -1.0
      case .worse: return -0.5
      case .neutral: return 0.0
      case .better: return 0.5
      case .wayBetter: return 1.0
      }
   }
}

struct AverageRatingResponse: Codable {
   let averageRating: Double
}


