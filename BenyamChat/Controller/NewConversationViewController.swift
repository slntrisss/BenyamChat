//
//  NewConversationViewController.swift
//  BenyamChat
//
//  Created by Raiymbek Merekeyev on 09.12.2022.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult) -> ())?
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String: String]]()
    private var hasFetched = false
    private var results = [SearchResult]()
    
    private var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Seacrh for users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        return tableView
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        label.textAlignment = .center
        label.text = "No Results"
        label.textColor = .green
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        searchBar.delegate = self
        navigationController?.navigationBar.topItem?.titleView = searchBar
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(dismissSelf))
        
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @objc private func dismissSelf(){
        dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: (view.width / 4),
                                      y: (view.height - 200) / 2,
                                      width: view.width / 2,
                                      height: 200)
    }

}

extension NewConversationViewController: UISearchBarDelegate{
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else{
            return
        }
        searchBar.resignFirstResponder()
        results.removeAll()
        spinner.show(in: view)
        self.searchUsers(query: text)
    }
    
    func searchUsers(query: String){
        if hasFetched{
            self.filterUsers(with: query)
        }else{
            DatabaseManager.shared.getAllUsers(completion: {[weak self]result in
                switch result {
                case .success(let users):
                    self?.hasFetched = true
                    self?.users = users
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("Failed to fetch all users: \(error)")
                }
            })
        }
    }
    func filterUsers(with term: String){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String, hasFetched else{
            return
        }
        
        let safeEmail = DatabaseManager.shared.safeEmail(emailAddress: currentEmail)
        
        spinner.dismiss(animated: true)
        let results: [SearchResult] = users.filter({
            guard let email = $0["email"], email != safeEmail else{
                return false
            }
            
            guard let user = $0["name"]?.lowercased() else{
                return false
            }
            return user.hasPrefix(term.lowercased())
        }).compactMap({
            guard let email = $0["email"], let name = $0["name"] else{
                return nil
            }
            return SearchResult(name: name, email: email)
        })
        
        self.results = results
        updateUI()
    }
    
    func updateUI(){
        if results.isEmpty{
            noResultsLabel.isHidden = false
            tableView.isHidden = true
        }else{
            noResultsLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as! NewConversationCell
        cell.configure(with: results[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let targetUserData = results[indexPath.row]
        
        dismiss(animated: true, completion: { [weak self] in
            self?.completion?(targetUserData)
        })
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}

struct SearchResult{
    let name: String
    let email: String
}
