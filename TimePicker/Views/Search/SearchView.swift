//
//  SearchView.swift
//  TimePicker
//
//  Created by Kazuya Ueoka on 2020/02/06.
//  Copyright © 2020 fromKK. All rights reserved.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading) {
                Group {
                    Text("Date").bold()
                    SearchDateView(selectedSearchDateType: $viewModel.searchDateType)
                    Text("Min free time").bold()
                    DatePickerView(datePickerModel: .countDownTimer, date: $viewModel.minFreeTimeDate, text: $viewModel.minFreeTimeText)
                    Text("Search range").bold()
                    HStack {
                        DatePickerView(datePickerModel: .time, date: $viewModel.fromTime, text: $viewModel.fromText)
                        Text(" - ")
                        DatePickerView(datePickerModel: .time, date: $viewModel.toTime, text: $viewModel.toText)
                    }
                    Text("Transit time").bold()
                    DatePickerView(datePickerModel: .countDownTimer, date: $viewModel.transitTimeDate, text: $viewModel.transitTimeText)
                    Toggle(isOn: $viewModel.ignoreAllDays, label: {
                        Text("Ignore all days").bold()
                    })
                }
                Spacer(minLength: 32)
                Button(action: {
                    self.search()
                }, label: {
                    Text("Search")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .foregroundColor(Color.white)
                })
                    .frame(height: 48)
                    .background(self.viewModel.isValid ? Color.blue : Color.gray)
                    .cornerRadius(24)
                    .disabled(!self.viewModel.isValid)
            }
        }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
    }

    private func search() {
        viewModel.search = ()
    }

    private func endEditing() {
        UIApplication.shared.endEditing()
    }
}

struct SearchView_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            SearchView(viewModel: SearchViewModel())
        }
    }
}
