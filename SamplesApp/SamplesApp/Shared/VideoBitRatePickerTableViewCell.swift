import UIKit

enum VideoBitRateOptions {
  static let list: [(title: String, value: Int?)] = [
    ("未指定", nil),
    ("100", 100),
    ("300", 300),
    ("500", 500),
    ("800", 800),
    ("1000", 1000),
    ("1500", 1500),
    ("2000", 2000),
    ("2500", 2500),
    ("3000", 3000),
    ("5000", 5000),
    ("10000", 10000),
    ("15000", 15000),
    ("20000", 20000),
    ("30000", 30000),
  ]
}

class VideoBitRatePickerTableViewCell: UITableViewCell, UIPickerViewDelegate,
  UIPickerViewDataSource
{
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var valueTextField: UITextField!

  private let pickerView = UIPickerView()
  private var selectedIndex = 0

  var selectedBitRate: Int? {
    VideoBitRateOptions.list[selectedIndex].value
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    configurePicker()
  }

  func focusPicker() {
    valueTextField.becomeFirstResponder()
  }

  func selectBitRate(_ value: Int?) {
    if let value,
      let index = VideoBitRateOptions.list.firstIndex(where: { $0.value == value })
    {
      selectedIndex = index
    } else {
      selectedIndex = 0
    }
    pickerView.selectRow(selectedIndex, inComponent: 0, animated: false)
    valueTextField.text = VideoBitRateOptions.list[selectedIndex].title
  }

  private func configurePicker() {
    valueTextField.inputView = pickerView
    pickerView.delegate = self
    pickerView.dataSource = self
    pickerView.selectRow(selectedIndex, inComponent: 0, animated: false)
    valueTextField.text = VideoBitRateOptions.list[selectedIndex].title

    let toolbar = UIToolbar()
    toolbar.sizeToFit()
    toolbar.setItems(
      [
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
        UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(onDoneButton)),
      ],
      animated: false)
    valueTextField.inputAccessoryView = toolbar
  }

  @objc private func onDoneButton() {
    valueTextField.resignFirstResponder()
  }

  // MARK: UIPickerViewDataSource

  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    1
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    VideoBitRateOptions.list.count
  }

  // MARK: UIPickerViewDelegate

  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int)
    -> String?
  {
    VideoBitRateOptions.list[row].title
  }

  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    selectedIndex = row
    valueTextField.text = VideoBitRateOptions.list[row].title
  }
}
