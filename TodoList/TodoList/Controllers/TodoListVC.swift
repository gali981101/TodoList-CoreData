//
//  ViewController.swift
//  TodoList
//
//  Created by Terry Jason on 2023/12/4.
//

import UIKit
import CoreData

class TodoListVC: UITableViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    var selectedCategory: Category? {
        didSet {
            loadItems()
        }
    }
    
    lazy var itemArray: [Item] = []
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUp()
        self.title = selectedCategory?.name
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        view.endEditing(true)
    }
    
}

// MARK: - SetUp

extension TodoListVC {
    
    private func setUp() {
        addButtonSet()
        searchBarDelegateSetUp()
        tableViewDragDelegate()
        hideKeyboardWhenTappedAround()
    }
    
    private func addButtonSet() {
        let addButton = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .done, target: self, action: #selector(addToDo))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        addButton.tintColor = .label
        self.toolbarItems = [flexibleSpace, addButton]
    }
    
    private func searchBarDelegateSetUp() {
        searchBar.delegate = self
    }
    
    private func tableViewDragDelegate() {
        tableView.dragDelegate = self
        tableView.dragInteractionEnabled = true
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: true)
    }
    
}

// MARK: - @Objc Func

extension TodoListVC {
    
    @objc private func addToDo() {
        var textField = UITextField()
        
        let alert = UIAlertController(title: "新增待辦事項", message: "", preferredStyle: .alert)
        
        let cancel = UIAlertAction(title: "取消", style: .destructive)
        let sure = UIAlertAction(title: "確定", style: .cancel) { [self] _ in
            guard textField.text != "" else { return }
            
            let newItem = Item(context: context)
            newItem.title = textField.text!
            newItem.done = false
            newItem.parentCategory = selectedCategory
            
            itemArray.append(newItem)
            saveItems()
        }
        
        alert.addAction(sure)
        alert.addAction(cancel)
        
        alert.addTextField {
            $0.placeholder = "寫些什麼..."
            textField = $0
        }
        
        self.present(alert, animated: true) {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissAlert))
            alert.view.superview?.subviews[0].addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func dismissAlert() {
        self.dismiss(animated: true)
    }
    
}

// MARK: - UISearchBarDelegate

extension TodoListVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", searchBar.text!)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        loadItems(request, predicate)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text?.count == 0 {
            loadItems()
            Task { @MainActor in
                searchBar.resignFirstResponder()
            }
        }
    }
    
}

// MARK: - UITableViewDataSource

extension TodoListVC {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ToDoItemCell", for: indexPath)
        
        let item = itemArray[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        
        cell.accessoryType = item.done ? .checkmark : .none
        cell.tintColor = .label
        cell.contentConfiguration = content
        
        return cell
    }
    
}

// MARK: - UITableViewDelegate

extension TodoListVC {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        itemArray[indexPath.row].done.toggle()
        saveItems()
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: "Delete") { [self] (action, view, completion) in
            context.delete(itemArray[indexPath.row])
            itemArray.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            saveItems()
            
            completion(true)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let mover = itemArray.remove(at: sourceIndexPath.row)
        itemArray.insert(mover, at: destinationIndexPath.row)
        saveItems()
    }
    
}

// MARK: - UITableViewDragDelegate

extension TodoListVC: UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = itemArray[indexPath.row]
        return [dragItem]
    }
    
}

// MARK: - Data Manupulation Func

extension TodoListVC {
    
    private func saveItems() {
        do {
            try context.save()
            tableView.reloadData()
        } catch {
            print("Saving Context Error...\(error.localizedDescription)")
        }
    }
    
    private func loadItems(_ request: NSFetchRequest<Item> = Item.fetchRequest(), _ predicate: NSPredicate? = nil) {
        let categoryPredicate = NSPredicate(format: "parentCategory.name MATCHES %@", selectedCategory!.name!)
        
        if let predicate = predicate {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [categoryPredicate, predicate])
        } else {
            request.predicate = categoryPredicate
        }
        
        do {
            let items = try context.fetch(request)
            itemArray = items
            tableView.reloadData()
        } catch {
            print("Fetch Context Error...\(error.localizedDescription)")
        }
    }
    
}




