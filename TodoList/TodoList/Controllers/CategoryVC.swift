//
//  CategoryVC.swift
//  TodoList
//
//  Created by Terry Jason on 2023/12/8.
//

import UIKit
import CoreData

class CategoryVC: UITableViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    lazy var categoriesArray: [Category] = []
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUp()
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        view.endEditing(true)
    }
    
}

// MARK: - SetUp

extension CategoryVC {
    
    private func setUp() {
        addCategoryButtonSet()
        searchBarDelegateSetUp()
        tableViewDragDelegate()
        hideKeyboardWhenTappedAround()
        loadCategories()
    }
    
    private func addCategoryButtonSet() {
        let addButton = UIBarButtonItem(image: UIImage(systemName: "folder.fill.badge.plus"), style: .done, target: self, action: #selector(addCategory))
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

extension CategoryVC {
    
    @objc private func addCategory() {
        
        var textField = UITextField()
        
        let alert = UIAlertController(title: "新增待辦類別", message: "", preferredStyle: .alert)
        let cancelButton = UIAlertAction(title: "取消", style: .destructive)
        let sureButton = UIAlertAction(title: "確定", style: .cancel) { [self] _ in
            guard textField.text != "" else { return }
            
            let newCategory = Category(context: context)
            newCategory.name = textField.text!
            
            categoriesArray.append(newCategory)
            saveCategories()
        }
        
        alert.addAction(sureButton)
        alert.addAction(cancelButton)
        
        alert.addTextField {
            $0.placeholder = "填寫類別名稱"
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

extension CategoryVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchBar.text!)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        loadCategories(request)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text?.count == 0 {
            loadCategories()
            Task { @MainActor in
                searchBar.resignFirstResponder()
            }
        }
    }
    
}

// MARK: - UITableViewDataSource

extension CategoryVC {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categoriesArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        let category = categoriesArray[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = category.name
        content.image = UIImage(systemName: "folder")
        
        cell.contentConfiguration = content
        return cell
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: "Delete") { [self] (action, view, completion) in
            context.delete(categoriesArray[indexPath.row])
            categoriesArray.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            saveCategories()
            
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
        let mover = categoriesArray.remove(at: sourceIndexPath.row)
        categoriesArray.insert(mover, at: destinationIndexPath.row)
        saveCategories()
    }
    
}

// MARK: - UITableViewDelegate

extension CategoryVC {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "goToItems", sender: self)
    }
    
}

// MARK: - UITableViewDragDelegate

extension CategoryVC: UITableViewDragDelegate {
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = categoriesArray[indexPath.row]
        return [dragItem]
    }
    
}

// MARK: - Segue

extension CategoryVC {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToItems" {
            guard let destinationVC = segue.destination as? TodoListVC else { return }
            guard let indexPath = tableView.indexPathForSelectedRow else { return }
            
            destinationVC.selectedCategory = categoriesArray[indexPath.row]
        }
    }
    
}

// MARK: - Data Manupulation Func

extension CategoryVC {
    
    private func saveCategories() {
        do {
            try context.save()
            tableView.reloadData()
        } catch {
            print("Saving Context Error...\(error.localizedDescription)")
        }
    }
    
    private func loadCategories(_ request: NSFetchRequest<Category> = Category.fetchRequest()) {
        do {
            let categories = try context.fetch(request)
            categoriesArray = categories
            tableView.reloadData()
        } catch {
            print("Loading Context Error...\(error.localizedDescription)")
        }
    }
    
}
