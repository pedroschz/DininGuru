//
//  DiningService.swift
//  DininGuru
//
//  Created by Pedro Sánchez-Gil Galindo on 11/22/24.
//

import SwiftUI

// MARK: - DiningService
// handles fetching data for dining venues from the API or a backup source

class DiningService {
   private let apiUrl = "https://pennmobile.org/api/dining/venues/" //primary API endpoint
   private let backupApiUrl = "https://pennlabs.github.io/backup-data/venues.json" //backup API endpoint
   
   // fetches dining data from the primary API
   func fetchDiningData(completion: @escaping (Result<[Venue], Error>) -> Void) {
      guard let url = URL(string: apiUrl) else {
         completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil))) // TODO: better error handling
         return
      }
      
      URLSession.shared.dataTask(with: url) { data, response, error in
         if let error = error {
            print("API request failed, trying backup API: \(error.localizedDescription)") // logs error
            self.fetchBackupDiningData(completion: completion) //tries backup API if error occurs
            return
         }
         
         guard let data = data else { // no data from API
            self.fetchBackupDiningData(completion: completion) //fallback to backup API
            return
         }
         
         do {
            let venues = try JSONDecoder().decode([Venue].self, from: data) // attempts to decode data
            DispatchQueue.main.async {
               completion(.success(venues)) // returns success
            }
         } catch {
            self.fetchBackupDiningData(completion: completion) //handle decoding failure by trying backup API
            // MARK: check if backup is always necessary or if it could retry primary API once
         }
      }.resume()
   }
   
   // fetches dining data from the backup API
   private func fetchBackupDiningData(completion: @escaping (Result<[Venue], Error>) -> Void) {
      guard let url = URL(string: backupApiUrl) else {
         completion(.failure(NSError(domain: "Invalid Backup URL", code: -1, userInfo: nil))) // TODO: validate backup URL earlier?
         return
      }
      
      URLSession.shared.dataTask(with: url) { data, response, error in
         if let error = error {
            DispatchQueue.main.async {
               completion(.failure(error)) // failed to get data even from backup
            }
            return
         }
         
         guard let data = data else { // no data from backup API
            DispatchQueue.main.async {
               completion(.failure(NSError(domain: "No Data", code: -1, userInfo: nil)))
            }
            return
         }
         
         do {
            let venues = try JSONDecoder().decode([Venue].self, from: data) // decode backup data
            DispatchQueue.main.async {
               completion(.success(venues)) //returns success from backup
            }
         } catch {
            DispatchQueue.main.async {
               completion(.failure(error)) // failed to decode backup data
            }
            // TODO: log error or notify user about the issue with backup data
         }
      }.resume()
   }
}
