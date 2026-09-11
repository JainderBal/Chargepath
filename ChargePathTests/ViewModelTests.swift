//
//  ViewModelTests.swift
//  ChargePathTests
//

import XCTest
import RxSwift
@testable import ChargePath

@MainActor
final class MapViewModelTests: XCTestCase {

    private var bag = DisposeBag()

    private func makeSUT(
        stations: [Station],
        bookmarks: Set<String> = []
    ) -> (MapViewModel, StationRepositoryDouble, BookmarkRepositoryDouble, LocationServiceDouble) {
        let stationRepo = StationRepositoryDouble(stations)
        let bookmarkRepo = BookmarkRepositoryDouble(bookmarks)
        let location = LocationServiceDouble()
        let vm = MapViewModel(
            stationRepository: stationRepo,
            bookmarkRepository: bookmarkRepo,
            vehicleRepository: VehicleRepositoryDouble(),
            localizationRepository: LocalizationRepositoryDouble(),
            locationService: location,
            chargingSessionRepository: ChargingSessionRepositoryDouble()
        )
        return (vm, stationRepo, bookmarkRepo, location)
    }

    func test_visibleStations_starts_with_all_stations() {
        let (vm, _, _, _) = makeSUT(stations: [
            Fixture.station(id: "a"), Fixture.station(id: "b"), Fixture.station(id: "c")
        ])
        XCTAssertEqual(vm.visibleStations.value.map(\.id).sorted(), ["a", "b", "c"])
    }

    func test_bookmarked_segment_filters_to_bookmarks() {
        let (vm, _, _, _) = makeSUT(
            stations: [Fixture.station(id: "a"), Fixture.station(id: "b")],
            bookmarks: ["b"]
        )
        vm.setSegment(.bookmarked)
        XCTAssertEqual(vm.visibleStations.value.map(\.id), ["b"])
    }

    func test_query_narrows_visible_stations() {
        let (vm, _, _, _) = makeSUT(stations: [
            Fixture.station(id: "a", name: "Marché Central"),
            Fixture.station(id: "b", name: "Plateau Garage")
        ])
        vm.updateQuery("plateau")
        XCTAssertEqual(vm.visibleStations.value.map(\.id), ["b"])
    }

    func test_resultLine_reflects_count() {
        let (vm, _, _, _) = makeSUT(stations: [Fixture.station(id: "a"), Fixture.station(id: "b")])
        XCTAssertEqual(vm.resultLine.value, "2 stations nearby")
    }

    func test_onAppear_requests_location_permission() {
        let (vm, _, _, location) = makeSUT(stations: [])
        vm.onAppear()
        XCTAssertEqual(location.requestWhenInUseCallCount, 1)
    }

    func test_locateTapped_asks_for_a_fix() {
        let (vm, _, _, location) = makeSUT(stations: [])
        vm.locateTapped()
        XCTAssertEqual(location.requestLocationCallCount, 1)
    }

    func test_selectStation_calls_navigation_hook() {
        let (vm, _, _, _) = makeSUT(stations: [Fixture.station(id: "a", name: "Pick me")])
        var picked: Station?
        vm.onSelectStation = { picked = $0 }
        vm.selectStation(id: "a")
        XCTAssertEqual(picked?.name, "Pick me")
    }
}

@MainActor
final class StationDetailViewModelTests: XCTestCase {

    func test_onAppear_merges_live_status_and_goes_live() {
        let station = Fixture.station(id: "s", ports: [
            ChargingPort(id: "p1", label: "P1", connector: .ccs, powerKW: 150, status: .available, note: nil),
            ChargingPort(id: "p2", label: "P2", connector: .ccs, powerKW: 150, status: .available, note: nil)
        ])
        let repo = StationRepositoryDouble([station])
        repo.liveStatusToMerge = ["p1": .inUse, "p2": .offline]

        let vm = StationDetailViewModel(
            station: station,
            stationRepository: repo,
            bookmarkRepository: BookmarkRepositoryDouble(),
            vehicleRepository: VehicleRepositoryDouble(),
            localizationRepository: LocalizationRepositoryDouble(),
            chargingSessionRepository: ChargingSessionRepositoryDouble()
        )
        vm.onAppear()

        XCTAssertEqual(vm.liveState.value, .live)
        XCTAssertEqual(vm.station.value.ports.first { $0.id == "p1" }?.status, .inUse)
        XCTAssertEqual(vm.station.value.ports.first { $0.id == "p2" }?.status, .offline)
    }

    func test_present_switches_to_another_station() {
        let a = Fixture.station(id: "a", name: "A")
        let b = Fixture.station(id: "b", name: "B")
        let vm = StationDetailViewModel(
            station: a,
            stationRepository: StationRepositoryDouble([a, b]),
            bookmarkRepository: BookmarkRepositoryDouble(),
            vehicleRepository: VehicleRepositoryDouble(),
            localizationRepository: LocalizationRepositoryDouble(),
            chargingSessionRepository: ChargingSessionRepositoryDouble()
        )
        vm.present(b)
        XCTAssertEqual(vm.station.value.id, "b")
    }

    func test_toggleBookmark_writes_through_repository() {
        let station = Fixture.station(id: "s")
        let bookmarks = BookmarkRepositoryDouble()
        let vm = StationDetailViewModel(
            station: station,
            stationRepository: StationRepositoryDouble([station]),
            bookmarkRepository: bookmarks,
            vehicleRepository: VehicleRepositoryDouble(),
            localizationRepository: LocalizationRepositoryDouble(),
            chargingSessionRepository: ChargingSessionRepositoryDouble()
        )
        XCTAssertFalse(vm.isBookmarked.value)
        vm.toggleBookmark()
        XCTAssertTrue(bookmarks.isBookmarked("s"))
        XCTAssertTrue(vm.isBookmarked.value)
    }
}
