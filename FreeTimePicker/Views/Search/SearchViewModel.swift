//
//  SearchViewModel.swift
//  TimePicker
//
//  Created by Kazuya Ueoka on 2020/02/06.
//  Copyright © 2020 fromKK. All rights reserved.
//

import Combine
import Core
import Foundation

final class SearchViewModel: ObservableObject {
    @Published var isValid: Bool = false
    @Published var searchDateType: SearchDateType?
    @Published var customStartDate: Date?
    @Published var customEndDate: Date?
    @Published var customStartText: String?
    @Published var customEndText: String?
    @Published var minFreeTimeDate: Date?
    @Published var minFreeTimeText: String?
    @Published var fromTime: Date?
    @Published var fromText: String?
    @Published var toTime: Date?
    @Published var toText: String?
    @Published var transitTimeDate: Date?
    @Published var transitTimeText: String?
    @Published var ignoreAllDays: Bool = true
    @Published var ignoreHolidays: Bool = true
    private var _search: PassthroughSubject<Void?, Never> = .init()

    private var cancellables: [AnyCancellable] = []

    typealias FromTo = (Date?, Date?, Date?, Date?)
    typealias RangeOfDates = (Date?, Date?)
    typealias Ignores = (allDay: Bool, holidays: Bool)
    @Published var result: [(Date, Date)] = []
    @Published var hasResults: Bool = false
    @Published var noResults: Bool = false

    let eventRepository: EventRepositoryProtocol
    let parametersStore: SearchParametersStore = .init()
    private let calculator: EventDateCalculator = .init()

    init(eventRepository: EventRepositoryProtocol) {
        self.eventRepository = eventRepository
        parametersStore.restore(with: self)
        bind()
    }

    private func bind() {
        let fromTo = Publishers.CombineLatest4($fromTime, $toTime, $customStartDate, $customEndDate)
        let freeTimeAndTransitTime = Publishers.CombineLatest($minFreeTimeDate, $transitTimeDate)
        let ignores = Publishers.CombineLatest($ignoreAllDays, $ignoreHolidays)
        let combine = Publishers.CombineLatest4($searchDateType, fromTo, freeTimeAndTransitTime, ignores).share()
        combine.sink { [weak self] arg in
            let (searchDateType, fromTo, freeTimeAndTransitTime, ignores) = arg
            self?.handleIsValid(searchDateType: searchDateType, fromTo: fromTo, freeTimeAndTransitTime: freeTimeAndTransitTime, ignores: ignores)
        }.store(in: &cancellables)

        _search
            .combineLatest(combine)
            .filter { $0.0 != nil }
            .map { $0.1 }
            .sink { [weak self] searchDateType, fromTo, freeTimeAndTransitTime, ignores in
                guard let searchDateType = searchDateType else { return }
                self?.performSearch(searchDateType: searchDateType, fromTo: fromTo, freeTimeAndTransitTime: freeTimeAndTransitTime, ignores: ignores)
            }.store(in: &cancellables)
    }

    func search() {
        _search.send(())
        _search.send(nil)
    }

    private func handleIsValid(searchDateType: SearchDateType?, fromTo: FromTo, freeTimeAndTransitTime: RangeOfDates, ignores _: Ignores) {
        let isValidCustom: Bool = {
            if case .custom = searchDateType {
                if let startDate = fromTo.2?.startOfDay(), let endDate = fromTo.3?.endOfDay() {
                    return startDate <= endDate
                } else {
                    return false
                }
            } else {
                return true
            }
        }()

        let isValidTimeInterval: Bool = {
            guard let from = fromTo.0, let to = fromTo.1, let freeTime = freeTimeAndTransitTime.0, let transitTime = freeTimeAndTransitTime.1 else {
                return false
            }
            let searchTimeInterval = from.distance(to: to)
            let minTimeInterval = self.timeInterval(of: freeTime) + self.timeInterval(of: transitTime) * 2
            return from <= to && minTimeInterval <= searchTimeInterval
        }()

        isValid = searchDateType != nil && isValidCustom && isValidTimeInterval && freeTimeAndTransitTime.0 != nil && freeTimeAndTransitTime.1 != nil
    }

    private func performSearch(searchDateType: SearchDateType, fromTo: FromTo, freeTimeAndTransitTime: RangeOfDates, ignores: Ignores) {
        guard let startTime = fromTo.0, let endTime = fromTo.1, let freeTime = freeTimeAndTransitTime.0, let transitTime = freeTimeAndTransitTime.1 else {
            return
        }

        let from: Date, to: Date
        if case .custom = searchDateType {
            if let start = fromTo.2?.startOfDay(), let end = fromTo.3?.endOfDay() {
                from = start
                to = end
            } else {
                return
            }
        } else {
            guard let (start, end) = searchDateType.dates() else {
                return
            }
            from = start
            to = end
        }

        eventRepository.fetch(startDate: from, endDate: to, ignoreAllDay: ignores.allDay)
            .sink { [weak self] events in
                guard let self = self else { return }
                self.searchFreeTime(
                    in: events,
                    from: from,
                    to: to,
                    startTime: startTime,
                    endTime: endTime,
                    freeTime: self.timeInterval(of: freeTime),
                    transitTime: self.timeInterval(of: transitTime),
                    ignoreAllDay: ignores.allDay,
                    ignoreHolidays: ignores.holidays
                )
            }.store(in: &cancellables)
    }

    private func timeInterval(of date: Date, calendar: Calendar = .init(identifier: .gregorian), timeZone: TimeZone = .current) -> TimeInterval {
        var calendar = calendar
        calendar.timeZone = timeZone
        let dateComponents = calendar.dateComponents([.hour, .minute], from: date)
        let minute: TimeInterval = 60.0
        let hour: TimeInterval = 60.0 * 60.0
        return TimeInterval(dateComponents.hour!) * hour + TimeInterval(dateComponents.minute!) * minute
    }

    private func searchFreeTime(in events: [EventEntity], from: Date, to: Date, startTime: Date, endTime: Date, freeTime: TimeInterval, transitTime: TimeInterval, ignoreAllDay _: Bool, ignoreHolidays: Bool) {
        parametersStore.save(with: self)
        result = FreeTimeFinder.find(
            with: calculator,
            in: events,
            from: from,
            to: to,
            startTime: startTime,
            endTime: endTime,
            freeTime: freeTime,
            transitTime: transitTime,
            ignoreAllDay: ignoreAllDays,
            ignoreHolidays: ignoreHolidays
        )
        hasResults = result.count > 0
        noResults = result.count == 0
    }
}
