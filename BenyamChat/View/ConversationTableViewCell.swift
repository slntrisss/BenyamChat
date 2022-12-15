//
//  ConversationTableViewCell.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 14.12.2022.
//

import UIKit
import SDWebImage

class ConversationTableViewCell: UITableViewCell {
    
    static let identifier = "ConversationTableViewCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 50
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userNameLabel: UILabel = {
        let userNameLabel = UILabel()
        userNameLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        return userNameLabel
    }()
    
    private let userMessageLabel: UILabel = {
        let messageLabel = UILabel()
        messageLabel.font = .systemFont(ofSize: 19, weight: .regular)
        messageLabel.numberOfLines = 0
        return messageLabel
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(userMessageLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 10,
                                     y: 10,
                                     width: 100,
                                     height: 100)
        
        userNameLabel.frame = CGRect(x: userImageView.right + 10,
                                     y: 10,
                                     width: contentView.width - 20 - userImageView.width,
                                     height: (contentView.height - 20) / 2)
        
        userMessageLabel.frame = CGRect(x: userImageView.right + 10,
                                        y: userNameLabel.bottom + 10,
                                        width: contentView.width - 20 - userImageView.width,
                                        height: (contentView.height - 20) / 2)
    }
    
    public func configure(with model: Conversation){
        self.userNameLabel.text = model.name
        self.userMessageLabel.text = model.latestMessage.message
        
        let path = "images/\(model.otherUSerEmail)_profile_image.png"
        StorageManager.shared.downloadURL(for: path, completion: {[weak self]result in
            switch result{
            case .success(let url):
                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url)
                }
            case .failure(let error):
                print("Failed to download profile picture: \(error)")
            }
        })
    }

}
