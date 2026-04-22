//
//  AdvancedTaskField.swift
//  LifeTrack
//
//  Category-driven advanced fields shown in the NewTaskView advanced section.
//  Stored on LifeTask as a JSON-encoded [String: String] in
//  templateMetadataRawValue. Tasks predating this feature simply hold an empty
//  dictionary, which is why LifeTask's default ("") is safe on existing rows.
//

import Foundation

enum AdvancedTaskField: String, CaseIterable, Identifiable {
    case provider
    case dosage
    case amount
    case payee
    case recipient
    case meetingLink
    case area
    case supplies
    case withWhom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .provider: "Provider"
        case .dosage: "Dosage"
        case .amount: "Amount"
        case .payee: "Payee"
        case .recipient: "Recipient"
        case .meetingLink: "Meeting link"
        case .area: "Area"
        case .supplies: "Supplies"
        case .withWhom: "With whom"
        }
    }

    var placeholder: String {
        switch self {
        case .provider: "Dr. Smith, Oak Clinic"
        case .dosage: "500mg · 2 tablets"
        case .amount: "$42.50"
        case .payee: "Con Edison"
        case .recipient: "jane@company.com"
        case .meetingLink: "https://meet.link/abc"
        case .area: "Kitchen, bathroom"
        case .supplies: "Vacuum, wipes"
        case .withWhom: "Sam, Alex"
        }
    }

    var symbolName: String {
        switch self {
        case .provider: "stethoscope"
        case .dosage: "pills"
        case .amount: "dollarsign.circle"
        case .payee: "building.2"
        case .recipient: "at"
        case .meetingLink: "link"
        case .area: "square.grid.2x2"
        case .supplies: "shippingbox"
        case .withWhom: "person.2"
        }
    }

    /// AI prompt hint describing what to put in this field.
    var aiHint: String {
        switch self {
        case .provider: "Doctor, clinic, or health provider name."
        case .dosage: "Medication dosage (e.g. 500mg, 2 tablets)."
        case .amount: "Monetary amount with currency symbol if stated."
        case .payee: "Vendor, company, or person receiving payment."
        case .recipient: "Email address or name of recipient."
        case .meetingLink: "Meeting URL (zoom, meet, teams, etc.)."
        case .area: "Room or area of the home."
        case .supplies: "Items or tools needed."
        case .withWhom: "Names of people involved."
        }
    }
}

extension TaskCategory {
    var advancedFields: [AdvancedTaskField] {
        switch self {
        case .health: [.provider, .dosage]
        case .finance: [.amount, .payee]
        case .work: [.recipient, .meetingLink]
        case .home: [.area, .supplies]
        case .personal: [.withWhom]
        case .other: []
        }
    }
}
