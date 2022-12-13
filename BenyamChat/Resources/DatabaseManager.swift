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
    
    func safeEmail(emailAddress: String) -> String{
        return emailAddress.replacingOccurrences(of: ".", with: "-").replacingOccurrences(of: "@", with: "-")
    }
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
            
            self.database.child("users").observeSingleEvent(of: .value, with: {[weak self] snapshot in
                if var usersCollection = snapshot.value as? [[String: String]]{
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    self?.database.child("users").setValue(usersCollection, withCompletionBlock: {error, _ in
                        guard error == nil else{
                            completeion(false)
                            print("Failed to append new user to database: \(String(describing: error))")
                            return
                        }
                        completeion(true)
                    })
                }
                else{
                    let usersCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    
                    self?.database.child("users").setValue(usersCollection, withCompletionBlock: {error, _ in
                        guard error == nil else{
                            completeion(false)
                            print("Failed to create new collection of users: \(String(describing: error))")
                            return
                        }
                        completeion(true)
                    })
                }
            })
            
            
            
            completeion(true)
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> ()){
        self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
            guard let users = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(users))
        })
    }
    
    public enum DatabaseError: Error{
        case failedToFetch
    }
}

extension DatabaseManager{
    
    ///Creates a new conversation with target user  email and first message sent
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> ()){
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: senderEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            let formattedDate = ChatViewController.dateFormatter.string(from: firstMessage.sentDate)
            var message = ""
            
            switch firstMessage.kind{
            case .text(let text):
                message = text
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "latest_message": [
                    "date": formattedDate,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                conversations.append(newConversationData)
                ref.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
            }else{
                userNode["conversation"] = [newConversationData]
                ref.setValue(userNode, withCompletionBlock: {error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self.finishCreatingConversation(conversationID: conversationId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> ()){
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        
        let conversationId = "conversation_\(firstMessage.messageId)"
        let formattedDate = ChatViewController.dateFormatter.string(from: firstMessage.sentDate)
        
        var message = ""
        
        switch firstMessage.kind{
        case .text(let text):
            message = text
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageTypeDescriprion,
            "content": message,
            "date": formattedDate,
            "sender_email": email,
            "is_read": false
        ]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: {error, _ in
            guard error == nil else{
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Fetches and returns all conversations for the user with email
    public func getAllConversations(for email:String, completion: @escaping (Result<String, Error>) -> ()){
        
    }
    
    ///Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<String, Error>) -> ()){
        
    }
    
    ///Sends a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, completion: @escaping (Bool) -> ()){
        
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
