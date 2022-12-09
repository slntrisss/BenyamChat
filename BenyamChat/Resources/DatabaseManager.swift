//
//  DatabaseManager.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 08.12.2022.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager{
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
}

//MARK: - Account mgmt
extension DatabaseManager{
    
    public func userExists(with email: String, completion: @escaping((Bool) -> Void)){
        let safeEmail = email.replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "@", with: "-")
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Insert new user to database
    public func insertUser(with user: ChatAppUser, completeion: @escaping (Bool) -> ()){
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else{
                print("Failed to insert user to database")
                completeion(false)
                return
            }
            completeion(true)
        })
    }
}

struct ChatAppUser{
    let firstName: String
    let lastName: String
    let email: String
    
    var safeEmail: String {
        return email.replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "@", with: "-")
    }
    
    var profileImageFileName: String {
        return "\(safeEmail)_profile_image.png"
    }
}