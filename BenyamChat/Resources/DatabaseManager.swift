//
//  DatabaseManager.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 08.12.2022.
//

import Foundation
import FirebaseDatabase
import MessageKit
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
    
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> ()){
        database.child(path).observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    ///Creates a new conversation with target user  email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> ()){
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String,
        let senderName = UserDefaults.standard.value(forKey: "name") as? String else{
            return
        }
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: senderEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: {[weak self] snapshot in
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
                "name": name,
                "latest_message": [
                    "date": formattedDate,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": senderName,
                "latest_message": [
                    "date": formattedDate,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {[weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                }
                else{
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                conversations.append(newConversationData)
                ref.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationId,
                                                     firstMessage: firstMessage,
                                                     completion: completion)
                })
            }else{
                userNode["conversations"] = [newConversationData]
                ref.setValue(userNode, withCompletionBlock: {error, _ in
                    guard error == nil else{
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                })
            }
        })
    }
    
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> ()){
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        
        let formattedDate = ChatViewController.dateFormatter.string(from: firstMessage.sentDate)
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: email)
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
            "sender_email": safeEmail,
            "is_read": false,
            "name": name
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
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> ()){
        print(email)
        database.child("\(email)/conversations").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({dict in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String,
                      let otherUserEmail = dict["other_user_email"] as? String,
                      let latestMessage = dict["latest_message"] as? [String: Any],
                      let sentDate = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else{
                    return nil
                }
                
                let latestMessageObject = LatestMessage(date: sentDate,
                                                        message: message,
                                                        isRead: isRead)
                
                return Conversation(id: id,
                                    name: name,
                                    otherUSerEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    ///Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> ()){
        database.child("\(id)/messages").observe(.value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap({ dict in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String,
                      let isRead = dict["is_read"] as? Bool,
                      let dateLabel = dict["date"] as? String,
                      let type = dict["type"] as? String,
                      let senderEmail = dict["sender_email"] as? String,
                      let content = dict["content"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateLabel) else{
                    return nil
                }
                
                var kind: MessageKind?
                
                if type == "photo"{
                    guard let imageUrl = URL(string: content),
                          let placeholder = UIImage(systemName: "plus") else{
                        return nil
                    }
                    let media = Media(url: imageUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    kind = .photo(media)
                }else if type == "video"{
                    guard let videoUrl = URL(string: content),
                          let placeholder = UIImage(named: "darkness") else{
                        return nil
                    }
                    let media = Media(url: videoUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    kind = .video(media)
                }
                else{
                    kind = .text(content)
                }
                
                guard let unwrappedKind = kind else{
                    return nil
                }
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                return Message(sender: sender,
                               messageId: id,
                               sentDate: date,
                               kind: unwrappedKind )
            })
            completion(.success(messages))
        })
    }
    
    ///Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, message: Message, completion: @escaping (Bool) -> ()){
        print("\n\nsend message with id:\(conversation)")
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: {[weak self] snapshot in
            guard var currentMessages = snapshot.value as? [[String: Any]],
            let email = UserDefaults.standard.value(forKey: "email") as? String,
            let strongSelf = self else{
                return
            }
            
            let formattedDate = ChatViewController.dateFormatter.string(from: message.sentDate)
            
            var newMessage = ""
            
            switch message.kind{
            case .text(let text):
                newMessage = text
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let photoMessageUrl = mediaItem.url?.absoluteString{
                    newMessage = photoMessageUrl
                }
                break
            case .video(let mediaItem):
                if let photoMessageUrl = mediaItem.url?.absoluteString{
                    newMessage = photoMessageUrl
                }
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
            
            let currentUserEmail = strongSelf.safeEmail(emailAddress: email)
            
            let newMessageEntry: [String: Any] = [
                "id": message.messageId,
                "type": message.kind.messageTypeDescriprion,
                "content": newMessage,
                "date": formattedDate,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages, withCompletionBlock: {error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String: Any]] else {
                        completion(false)
                        return
                    }

                    let updatedValue:[String: Any] = [
                        "date": formattedDate,
                        "is_read": false,
                        "message": newMessage
                    ]
                    var position = 0
                    var targetConversation:[String: Any]?
                    for currentUserConversation in currentUserConversations {
                        if let currentId = currentUserConversation["id"] as? String, currentId == conversation {
                            targetConversation = currentUserConversation
                            break
                        }
                        position += 1
                    }
                    targetConversation?["latest_message"] = updatedValue
                    guard let updatedTargetConversation = targetConversation else{
                        completion(false)
                        return
                    }

                    currentUserConversations[position] = updatedTargetConversation

                    strongSelf.database.child("\(currentUserEmail)/conversations").setValue(currentUserConversations, withCompletionBlock: {error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }

                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
                            guard var otherUserConversations = snapshot.value as? [[String: Any]] else {
                                completion(false)
                                return
                            }

                            let updatedValue:[String: Any] = [
                                "date": formattedDate,
                                "is_read": false,
                                "message": newMessage
                            ]
                            var position = 0
                            var targetConversation:[String: Any]?
                            for currentUserConversation in otherUserConversations {
                                if let currentId = currentUserConversation["id"] as? String, currentId == conversation {
                                    targetConversation = currentUserConversation
                                    break
                                }
                                position += 1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let updatedTargetConversation = targetConversation else{
                                completion(false)
                                return
                            }
                            otherUserConversations[position] = updatedTargetConversation
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations, withCompletionBlock: {error, _ in
                                guard error == nil else{
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
            })
        })
    }
    
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> ()){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        print("About to delete conversation with id: \(conversationId)")
        let safeEmail = safeEmail(emailAddress: email)
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var indexToRemove = 0
                
                for conversation in conversations{
                    if let id = conversation["id"] as? String, id == conversationId{
                        print("found conversation to delete")
                        break
                    }
                    indexToRemove += 1
                }
                
                conversations.remove(at: indexToRemove)
                ref.setValue(conversations) { error, _ in
                    guard error == nil else{
                        completion(false)
                        print("Failed to delete conversation")
                        return
                    }
                    print("Conversation deleted")
                    completion(true)
                }
            }
            
        }
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
