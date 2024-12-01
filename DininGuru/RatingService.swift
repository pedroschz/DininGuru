//
//  RatingService.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/24/24.
//

import Foundation

class RatingService {
   static let shared = RatingService()
   private init() {}

   
   func submitRating(venueId: String, rating: Double, userId: String, mealPeriod: String, completion: @escaping (Bool) -> Void) {
      guard let url = URL(string: "https://dininguru.onrender.com0/api/ratings") else {
         completion(false)
         return
      }
      
      let ratingData: [String: Any] = [
         "venue_id": venueId,
         "user_id": userId,
         "rating": rating,
         "meal_period": mealPeriod
      ]
      
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      
      do {
         let jsonData = try JSONSerialization.data(withJSONObject: ratingData, options: [])
         request.httpBody = jsonData
         
         URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
               print("Error submitting rating: \(error.localizedDescription)")
               completion(false)
               return
            }
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
               completion(true)
            } else {
               print("Failed to submit rating. Status Code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
               completion(false)
            }
         }.resume()
      } catch {
         print("Error encoding rating data: \(error.localizedDescription)")
         completion(false)
      }
   }
   
   func fetchAverageRating(venueId: String, completion: @escaping (Double?, Int?) -> Void) {

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
      
      let mealPeriod = getCurrentMealPeriod()
      
      guard let url = URL(string: "https://dininguru.onrender.com/api/ratings/\(venueId)/average?meal_period=\(mealPeriod)") else {
         completion(nil, nil)
         return
      }
      
      URLSession.shared.dataTask(with: url) { data, response, error in
         if let error = error {
            print("Error fetching average rating: \(error)")
            completion(nil, nil)
            return
         }
         guard let data = data,
               let result = try? JSONDecoder().decode(AverageRatingResponse.self, from: data) else {
            completion(nil, nil)
            return
         }
         completion(result.averageRating, result.reviewCount)
      }.resume()
      
   }
}

struct AverageRatingResponse: Codable {
   let averageRating: Double
   let reviewCount: Int
}

