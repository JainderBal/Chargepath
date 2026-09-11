//
//  Strings.swift
//  ChargePath
//
//  Every piece of user-facing copy, EN + FR. Ported from the `STR` object in
//  ChargePath.dc.html; entries that were inline ternaries in the mockup
//  (availability / power / radius option labels, wallet section titles, …)
//  are folded in here too.
//
//  Keep this the single source of copy — ViewModels format these into their
//  output relays; ViewControllers never hold string literals.
//

struct Strings {

    // MARK: Tabs / chrome
    let tabMap: String
    let tabRoute: String
    let tabSettings: String
    let tagline: String

    // MARK: Map
    let searchPlaceholder: String
    let segmentAll: String
    let segmentBookmarked: String
    /// "{n} stations nearby" — mockup `results(n)`.
    let resultsCount: (Int) -> String
    let emptyResultsTitle: String
    let emptyResultsBody: String

    // MARK: Filters
    let filtersTitle: String
    let filtersReset: String
    let filterConnectorType: String
    let filterAvailability: String
    let filterChargingSpeed: String
    let filterSearchRadius: String
    let filterCompatibleOnly: String
    let filterHideOfflineTitle: String
    let filterHideOfflineBody: String
    let filterApply: String
    let optAny: String
    let optAvailableNow: String
    let optTwoPortsFree: String
    let optLevel2: String
    let optRadiusAny: String

    // MARK: Station detail
    let stationPortsHeader: String
    let stationStartCharging: String
    let stationLive: String
    let stationCheckingStatus: String
    let stationStatusUpdated: String

    // MARK: Activate charging
    let activateTitle: String
    let activateSelectHeading: String
    let activatePayHeading: String
    let activateSandboxNote: String
    let activateConfirmButton: String
    let activateContinueButton: String
    let activateBackToMap: String
    let labelStation: String
    let labelPort: String
    let labelRate: String
    let labelHold: String
    let testModeBadge: String

    // MARK: Active charging session
    let sessionChargingHeading: String
    let sessionDoneHeading: String
    let sessionElapsed: String
    let sessionEnergy: String
    let sessionCost: String
    let sessionTotal: String
    let sessionDuration: String
    let sessionRate: String
    let sessionPower: String
    let sessionStop: String
    /// "Charging at {station} · {port} — tap to view" — map banner.
    let sessionMapBanner: (String) -> String
    let startChargingBusy: String

    // MARK: Route planner
    let routeInputHeading: String
    let routeStartPlaceholder: String
    let routeDestinationPlaceholder: String
    let routeVehicleProfileCaption: String
    let routeEditVehicle: String
    let routePlanButton: String
    let routePlanningButton: String
    let routePlanHint: String
    let routeResultsTitle: String

    // MARK: Settings
    let settingsTitle: String
    let settingsVehicleProfile: String
    let settingsLanguage: String
    let settingsAppInfo: String
    let settingsBookmarkedStations: String
    let settingsEmptyBookmarksTitle: String
    let settingsEmptyBookmarksBody: String

    // MARK: Wallet
    let walletTitle: String
    let walletSubtitle: String
    let walletAvailableBalance: String
    let walletPaymentHistory: String
    /// "Add $25 · Test Mode" — amount injected by the ViewModel.
    let walletAddFundsPrefix: String

    // MARK: Vehicle selection
    let vehicleTitle: String
    let vehicleBody: String
    let vehicleOrPickConnector: String
}

// MARK: - English

extension Strings {
    static let english = Strings(
        tabMap: "Map",
        tabRoute: "Route",
        tabSettings: "Settings",
        tagline: "EV charging · Montréal",

        searchPlaceholder: "Search a place or station",
        segmentAll: "All stations",
        segmentBookmarked: "Bookmarked",
        resultsCount: { "\($0) stations nearby" },
        emptyResultsTitle: "Nothing here yet",
        emptyResultsBody: "Try a wider search, or drop the bookmark filter to see everything nearby.",

        filtersTitle: "Filters",
        filtersReset: "Reset",
        filterConnectorType: "Connector type",
        filterAvailability: "Availability",
        filterChargingSpeed: "Charging speed",
        filterSearchRadius: "Search radius",
        filterCompatibleOnly: "Compatible with my car",
        filterHideOfflineTitle: "Hide offline stations",
        filterHideOfflineBody: "Only stations with a working port",
        filterApply: "Apply filters",
        optAny: "Any",
        optAvailableNow: "Available now",
        optTwoPortsFree: "2+ ports free",
        optLevel2: "Level 2 · ≤22 kW",
        optRadiusAny: "Any",

        stationPortsHeader: "Charging ports",
        stationStartCharging: "Start charging",
        stationLive: "Live",
        stationCheckingStatus: "Checking live status",
        stationStatusUpdated: "Status updated just now · refreshes every 30s",

        activateTitle: "Activate charging",
        activateSelectHeading: "Which port are you plugging into?",
        activatePayHeading: "Confirm your session",
        activateSandboxNote: "Sandbox card ending 4242 — a $25 hold is placed; you're billed for the energy you use. No real money moves in Test Mode.",
        activateConfirmButton: "Start charging (Test Mode)",
        activateContinueButton: "Continue",
        activateBackToMap: "Back to map",
        labelStation: "Station",
        labelPort: "Port",
        labelRate: "Rate",
        labelHold: "Pre-auth hold",
        testModeBadge: "TEST MODE",

        sessionChargingHeading: "Charging",
        sessionDoneHeading: "Charging complete",
        sessionElapsed: "Elapsed",
        sessionEnergy: "Energy",
        sessionCost: "Cost so far",
        sessionTotal: "Total charged",
        sessionDuration: "Duration",
        sessionRate: "Rate",
        sessionPower: "Power",
        sessionStop: "Stop charging",
        sessionMapBanner: { "Charging · \($0)" },
        startChargingBusy: "Finish your current session first",

        routeInputHeading: "Plan the whole run",
        routeStartPlaceholder: "Start location",
        routeDestinationPlaceholder: "Destination",
        routeVehicleProfileCaption: "From your vehicle profile",
        routeEditVehicle: "Edit",
        routePlanButton: "Plan trip",
        routePlanningButton: "Finding stops…",
        routePlanHint: "We add stops so you never dip below 15% charge.",
        routeResultsTitle: "Charging stops",

        settingsTitle: "Settings",
        settingsVehicleProfile: "Vehicle profile",
        settingsLanguage: "Language",
        settingsAppInfo: "App info",
        settingsBookmarkedStations: "Bookmarked stations",
        settingsEmptyBookmarksTitle: "No bookmarks yet",
        settingsEmptyBookmarksBody: "Tap the star on any station and it lands here for one-tap access.",

        walletTitle: "Wallet",
        walletSubtitle: "Charging balance",
        walletAvailableBalance: "Available balance",
        walletPaymentHistory: "Payment history",
        walletAddFundsPrefix: "Add ",

        vehicleTitle: "Which car are you charging?",
        vehicleBody: "We use this to highlight compatible connectors and auto-fill your range on trips.",
        vehicleOrPickConnector: "Or pick a connector"
    )
}

// MARK: - French

extension Strings {
    static let french = Strings(
        tabMap: "Carte",
        tabRoute: "Trajet",
        tabSettings: "Réglages",
        tagline: "Recharge VÉ · Montréal",

        searchPlaceholder: "Rechercher un lieu ou une borne",
        segmentAll: "Toutes les bornes",
        segmentBookmarked: "Favoris",
        resultsCount: { "\($0) bornes à proximité" },
        emptyResultsTitle: "Rien pour l’instant",
        emptyResultsBody: "Élargissez la recherche ou retirez le filtre favoris.",

        filtersTitle: "Filtres",
        filtersReset: "Réinitialiser",
        filterConnectorType: "Type de connecteur",
        filterAvailability: "Disponibilité",
        filterChargingSpeed: "Puissance",
        filterSearchRadius: "Rayon",
        filterCompatibleOnly: "Compatible avec ma voiture",
        filterHideOfflineTitle: "Bornes en service",
        filterHideOfflineBody: "Masquer les bornes hors service",
        filterApply: "Appliquer",
        optAny: "Toutes",
        optAvailableNow: "Libre maintenant",
        optTwoPortsFree: "2+ prises libres",
        optLevel2: "Niveau 2 · ≤22 kW",
        optRadiusAny: "Tout",

        stationPortsHeader: "Bornes de recharge",
        stationStartCharging: "Démarrer la recharge",
        stationLive: "En direct",
        stationCheckingStatus: "Vérification en direct",
        stationStatusUpdated: "Mis à jour à l’instant · toutes les 30 s",

        activateTitle: "Activer la recharge",
        activateSelectHeading: "Quelle prise utilisez-vous ?",
        activatePayHeading: "Confirmer la session",
        activateSandboxNote: "Carte test 4242 — une empreinte de 25 $ est posée ; vous payez l’énergie consommée. Aucun montant réel en mode test.",
        activateConfirmButton: "Démarrer la recharge (mode test)",
        activateContinueButton: "Continuer",
        activateBackToMap: "Retour à la carte",
        labelStation: "Borne",
        labelPort: "Prise",
        labelRate: "Tarif",
        labelHold: "Empreinte carte",
        testModeBadge: "MODE TEST",

        sessionChargingHeading: "Recharge en cours",
        sessionDoneHeading: "Recharge terminée",
        sessionElapsed: "Écoulé",
        sessionEnergy: "Énergie",
        sessionCost: "Coût actuel",
        sessionTotal: "Total facturé",
        sessionDuration: "Durée",
        sessionRate: "Tarif",
        sessionPower: "Puissance",
        sessionStop: "Arrêter la recharge",
        sessionMapBanner: { "Recharge · \($0)" },
        startChargingBusy: "Terminez d’abord votre session en cours",

        routeInputHeading: "Planifiez tout le trajet",
        routeStartPlaceholder: "Point de départ",
        routeDestinationPlaceholder: "Destination",
        routeVehicleProfileCaption: "Depuis votre profil véhicule",
        routeEditVehicle: "Modifier",
        routePlanButton: "Planifier",
        routePlanningButton: "Calcul des arrêts…",
        routePlanHint: "Nous ajoutons des arrêts pour rester au-dessus de 15 %.",
        routeResultsTitle: "Arrêts de recharge",

        settingsTitle: "Réglages",
        settingsVehicleProfile: "Profil du véhicule",
        settingsLanguage: "Langue",
        settingsAppInfo: "À propos",
        settingsBookmarkedStations: "Bornes favorites",
        settingsEmptyBookmarksTitle: "Aucun favori",
        settingsEmptyBookmarksBody: "Touchez l’étoile d’une borne pour la retrouver ici.",

        walletTitle: "Portefeuille",
        walletSubtitle: "Solde de recharge",
        walletAvailableBalance: "Solde disponible",
        walletPaymentHistory: "Historique",
        walletAddFundsPrefix: "Ajouter ",

        vehicleTitle: "Quelle voiture rechargez-vous ?",
        vehicleBody: "Sert à repérer les connecteurs compatibles et remplir votre autonomie.",
        vehicleOrPickConnector: "Ou choisir un connecteur"
    )
}
