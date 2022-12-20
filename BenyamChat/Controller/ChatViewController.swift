//
//  ChatViewController.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 09.12.2022.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

class ChatViewController: MessagesViewController {
    
    private var senderPhotoUrl: URL?
    private var otherUserPhotoUrl: URL?
    
    public static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    private var otherUserEmail: String
    private var conversationId: String?
    public var isNewConversation = false
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String,
              let name = UserDefaults.standard.value(forKey: "name") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: email)
        return Sender(photoURL: "",
               senderId: safeEmail,
               displayName: name)
    }
    
    init(with email: String, id: String?){
        self.otherUserEmail = email
        self.conversationId = id
        super.init(nibName: nil, bundle: nil)
        if let conversationId = conversationId {
            self.listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    private func setupInputButton(){
        let button = InputBarButtonItem()
        button.onTouchUpInside{ [weak self] _ in
            self?.presentInputActionSheet()
        }
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        messageInputBar.setLeftStackViewWidthConstant(to: 26, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Media",
                                            message: "What would you like to attach?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo",
                                            style: .default,
                                            handler: { [weak self] _ in
            self?.presentPhotoActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video",
                                            style: .default,
                                            handler: { [weak self] _ in
            self?.presentVideoActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Audio",
                                            style: .default,
                                            handler: {  _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Location",
                                            style: .default,
                                            handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker(){
        let vc = LocationViewController(coordinate: nil)
        vc.title = "Pick a Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinate in
            let longitude:Double = selectedCoordinate.longitude
            let latitude:Double = selectedCoordinate.latitude
            print("longitude: \(longitude)\nlatitude: \(latitude)")
            
            guard let stronSelf = self,
                  let messageId = stronSelf.createMessageId(),
                  let conversationId = stronSelf.conversationId,
                  let name = stronSelf.title,
                  let selfSender = stronSelf.selfSender else{
                return
            }
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                    size: .zero)
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: stronSelf.otherUserEmail, name: name, message: message, completion: {success in
                if success{
                    print("Sent location")
                }else{
                    print("Failed to send location")
                }
            })
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func presentPhotoActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Photo",
                                            message: "Where would you like to take photo from?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default,
                                            handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = true
            picker.delegate = self
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library",
                                            style: .default,
                                            handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.delegate = self
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func presentVideoActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Video",
                                            message: "Where would you like to take video from?",
                                            preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default,
                                            handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.delegate = self
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Library",
                                            style: .default,
                                            handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.delegate = self
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet, animated: true)
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool){
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: {[weak self] result in
            switch result{
            case .success(let messages):
                print("Success in getting messages: \(messages)")
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                }
                if shouldScrollToBottom{
                    self?.messagesCollectionView.scrollToLastItem()
                }
            case .failure(let error):
                print("Failed to fetch all messages: \(error)")
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            self.listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }

}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
              let selfSender = selfSender else{
            return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            let fileName = "photo_message_\(messageId.replacingOccurrences(of: " ", with: "-")).png"
            
            StorageManager.shared.uploadMessagePicture(with: imageData, fileName: fileName, completion: {[weak self] result in
                guard let strongSelf = self else{
                    return
                }
                switch result{
                case .success(let urlString):
                    print("Uploaded image with url: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else{
                        return
                    }
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, message: message, completion: {success in
                        if success{
                            print("Sent phtot")
                        }else{
                            print("Failed to send photo")
                        }
                    })
                case .failure(let error):
                    print("Message photo upload error: \(error)")
                }
            })
        }
        else if let videoURL = info[.mediaURL] as? URL {
            let fileName = "photo_message_\(messageId.replacingOccurrences(of: " ", with: "-")).mov"
            
            StorageManager.shared.uploadMessageURL(with: videoURL, fileName: fileName, completion: {[weak self] result in
                guard let strongSelf = self else{
                    return
                }
                switch result{
                case .success(let urlString):
                    print("Uploaded Video with url: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else{
                        return
                    }
                    let media = Media(url: url, image: nil, placeholderImage: placeholder, size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, message: message, completion: {success in
                        if success{
                            print("Sent phtot")
                        }else{
                            print("Failed to send photo")
                        }
                    })
                case .failure(let error):
                    print("Message photo upload error: \(error)")
                }
            })
        }
        
    }
}

extension ChatViewController: MessageCellDelegate{
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        
        let message = messages[indexPath.section]
        
        switch message.kind{
        case .location(let locationData):
            let coordinate = locationData.location.coordinate
            let vc = LocationViewController(coordinate: coordinate)
            vc.title = "Location"
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        
        let message = messages[indexPath.section]
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else{
                return
            }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
        default:
            break
        }
    }
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId{
            if let currentUserPhotoUrl = senderPhotoUrl{
                avatarView.sd_setImage(with: currentUserPhotoUrl)
            }
            else{
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_image.png"
                StorageManager.shared.downloadURL(for: path, completion: {[weak self] result in
                    switch result{
                    case .success(let url):
                        self?.senderPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print("Failed to fetch profile picture: \(error)")
                    }
                })
            }
        }
        else{
            if let otherUserPhotoUrl = self.otherUserPhotoUrl{
                avatarView.sd_setImage(with: otherUserPhotoUrl)
            }
            else{
                let email = otherUserEmail
                let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_image.png"
                StorageManager.shared.downloadURL(for: path, completion: {[weak self] result in
                    switch result{
                    case .success(let url):
                        self?.otherUserPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print("Failed to fetch profile picture: \(error)")
                    }
                })
            }
        }
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate{
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
        let selfSender = selfSender,
        let messageId = createMessageId() else {
            return
        }
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        self.messageInputBar.inputTextView.text = nil
        if isNewConversation{
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: message, completion: {[weak self] success in
                if success{
                    print("Message sent")
                    self?.isNewConversation = false
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                }else{
                    print("Failed to send message")
                }
            })
        }
        else{
            guard let conversationId = conversationId, let name = self.title else{
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, message: message, completion: {success in
                if success{
                    print("Message sent")
                }
                else{
                    print("Failed to sent message")
                }
            })
        }
    }
    
    private func createMessageId() -> String? {
        let date = Self.dateFormatter.string(from: Date())
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: senderEmail)
        let messageId = "\(otherUserEmail)_\(safeEmail)_\(date)"
        print(messageId)
        return messageId
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate{
    
    func currentSender() -> SenderType {
        if let sender = selfSender{
            return sender
        }
        fatalError("Sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else{
            return
        }
        
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else{
                return
            }
            imageView.sd_setImage(with: imageUrl)
        default:
            break
        }
    }
    
}
