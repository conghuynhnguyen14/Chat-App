//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Nguyen Cong Huynh on 13/11/2021.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
}

extension DatabaseManager{
    
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)){
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    // Insert new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void){
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print("Failed to wirte to database")
                completion(false)
                return
            }
            self.database.child("users").observeSingleEvent(of: .value) { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]]{
                    //append to user dictionary
                    let newElement = [
                        "name" : user.firstName + "" + user.lastName,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection) { (error, _) in
                        guard error == nil else {
                            return
                        }
                        completion(true)
                    }
                    
                }else {
                    //create that dictionary
                    let newCollection: [[String: String]] =  [
                        [
                            "name" : user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection) { (error, _) in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                }
            }
            completion(true)
        })
    }
    public func getAllUsers (completion: @escaping(Result <[[String: String]], Error >) -> Void){
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedtoFetch))
                return
            }
            completion(.success(value))
        }
    }
    public enum DatabaseError: Error{
        case failedtoFetch
    }
}

// MARK: - sending messages/conversation

extension DatabaseManager {
    
    // create a new converstaion with target user email and first mes sent
    public func createNewConversation (with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> (Void)) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: {snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            var messages = ""
            
            switch firstMessage.kind {
            case .text( let messageText):
                messages = messageText
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
                    "date": dateString,
                    "message": messages,
                    "is_read": false
                ]
            ]
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for curren user
                //you should append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                }
            } else {
                //conversation array does not exist
                //create it
                userNode["conversations"] = [newConversationData]
                ref.setValue(userNode) {[weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationId,
                                                    firstMessage: firstMessage,
                                                    completion: completion)
                }
            }
        })
    }
    
    private func finishCreatingConversation (conversationID: String, firstMessage: Message, completion: @escaping(Bool) -> Void){
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        var messages = ""
        switch firstMessage.kind {
        case .text( let messageText):
            messages = messageText
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
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.MessageKindString,
            "content": messages,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false
        ]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        database.child("\(conversationID)").setValue(value) { (error, _) in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    // fetches and return all conversation for the user with passed in email
    public func getAllConversations(for email: String,completion: @escaping (Result<String, Error>)  -> Void){
        
    }
    
    //Gets all messages for a given conversation
    public func getAllMessagesForConversation (with id: String, completion: @escaping(Result<String,Error>) -> Void){
         
    }
    
    // Sends a message with target conversation and message
    public func sendMessages(to conversation: String, messages: Message, completion: @escaping(Bool) -> (Void)){
        
    }
    
}


struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    var safeEmail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profileImageFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
    
}
