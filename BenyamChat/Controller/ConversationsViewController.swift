//
//  ConversationsViewController.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 27.11.2022.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation{
    let id: String
    let name: String
    let otherUSerEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage{
    let date: String
    let message: String
    let isRead: Bool
}

class ConversationsViewController: UIViewController {
    
    private var conversations = [Conversation]()
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var loginObserver: NSObjectProtocol?
    
    private var tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return table
    }()
    
    private let noConversationLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.text = "No Conversations!"
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        view.addSubview(noConversationLabel)
        setupTableView()
        startListenningForConversations()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                            target: self,
                                                            action: #selector(didTapComposeButton))
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLoginNotification, object: nil, queue: .main, using: {[weak self] _ in
            guard let strongSelf = self else{
                return
            }
            
            strongSelf.startListenningForConversations()
        })
    }
    
    private func startListenningForConversations(){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        
        if let observer = loginObserver{
            NotificationCenter.default.removeObserver(observer)
        }
        
        print("starting conversation fetching...")
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: {[weak self] result in
            switch result{
            case .success(let conversations):
                print("Successfully got conversation models")
                guard !conversations.isEmpty else{
                    self?.tableView.isHidden = true
                    self?.noConversationLabel.isHidden = false
                    return
                }
                self?.tableView.isHidden = false
                self?.noConversationLabel.isHidden = true
                self?.conversations = conversations
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                self?.tableView.isHidden = true
                self?.noConversationLabel.isHidden = false
                print("Failed to fetch all user conversations: \(error)")
            }
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationLabel.frame = CGRect(x: 10,
                                           y: (view.height - 100) / 2,
                                           width: view.width - 20,
                                           height: 100)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        validateUser()
    }
    
    @objc private func didTapComposeButton(){
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            print("\(result)")
            
            let currentConversations = self?.conversations
            
            if let targetConversation = currentConversations?.first(where: {
                $0.otherUSerEmail == DatabaseManager.shared.safeEmail(emailAddress: result.email)
            }){
                let vc = ChatViewController(with: targetConversation.otherUSerEmail, id: targetConversation.id)
                vc.title = targetConversation.name
                vc.isNewConversation = false
                vc.navigationItem.largeTitleDisplayMode = .never
                self?.navigationController?.pushViewController(vc, animated: true)
            }else{
                self?.createNewConversation(result: result)
            }
        }
        let navBar = UINavigationController(rootViewController: vc)
        present(navBar, animated: true)
    }
    
    private func createNewConversation(result: SearchResult){
        let name = result.name
        let email = DatabaseManager.shared.safeEmail(emailAddress: result.email)
        
        DatabaseManager.shared.conversationExists(with: email, completion: {[weak self] result in
            switch result{
            case .success(let id):
                let vc = ChatViewController(with: email, id: id)
                vc.title = name
                vc.isNewConversation = false
                vc.navigationItem.largeTitleDisplayMode = .never
                self?.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                vc.title = name
                vc.isNewConversation = true
                vc.navigationItem.largeTitleDisplayMode = .never
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }
    
    private func validateUser(){
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
    }
    
    private func setupTableView(){
        tableView.delegate = self
        tableView.dataSource = self
    }

}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for: indexPath)
        as! ConversationTableViewCell
        cell.configure(with: conversations[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conversationModel = conversations[indexPath.row]
        openConversation(conversationModel)
    }
    
    func openConversation(_ conversationModel: Conversation){
        let vc = ChatViewController(with: conversationModel.otherUSerEmail, id: conversationModel.id)
        vc.title = conversationModel.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            DatabaseManager.shared.deleteConversation(conversationId: conversationId) { [weak self] succes in
                if succes{
                    self?.conversations.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }
            
            tableView.endUpdates()
        }
    }
}
