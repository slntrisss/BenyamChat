//
//  StorageManager.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 09.12.2022.
//

import Foundation
import FirebaseStorage

final class StorageManager{
    
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    ///Uploads profile picture to the database
    public func uploadProfileImage(with data: Data, fileName: String, completion: @escaping (Result<String, Error>) -> ()){
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { [weak self] metadata, error in
            guard error == nil, let strongSelf = self else{
                print("Failed to upload profile image")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            strongSelf.storage.child("images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else{
                    print("Failed to get dowload url back")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download url returned: \(urlString)")
                completion(.success(urlString))
            })
            
        })
    }
    
    ///Uploads message image data to the database
    public func uploadMessagePicture(with data: Data, fileName: String, completion: @escaping (Result<String, Error>) -> ()){
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: { [weak self] metadata, error in
            guard error == nil, let strongSelf = self else{
                print("Failed to upload message image")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            strongSelf.storage.child("message_images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else{
                    print("Failed to get dowload url back")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("Download url returned: \(urlString)")
                completion(.success(urlString))
            })
            
        })
    }
    
    public enum StorageErrors: Error{
        case failedToUpload
        case failedToGetDownloadUrl
    }
    
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> ()){
        let reference = storage.child(path)
        
        reference.downloadURL(completion: {url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            
            completion(.success(url))
        })
    }
}
