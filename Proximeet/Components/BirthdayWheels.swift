import SwiftUI
import UIKit
import ProximeetDomain

/// The approved Birthday console's day, month and year wheels: one native `UIPickerView`
/// with three components, so VoiceOver gets adjustable "Day", "Month" and "Year" wheels and
/// every value is announced.
///
/// Row 0 of each wheel is "not set" (DD / MMM / YYYY), so the screen starts with no date.
/// At rest a wheel draws exactly the rows the approved design shows: an unset wheel only its
/// placeholder, a set wheel its previous, selected and next values. Its other rows are drawn
/// clear, and are drawn normally from the moment a finger starts turning that wheel until
/// it settles. A value is reported only when a wheel settles on a row (`didSelectRow`), never while it
/// is still moving; `onMotion(true)` reports a finger turning a wheel, so Continue can wait
/// for the settled value. Model changes made elsewhere (typed entry) are applied without
/// animation and without reporting back.
struct BirthdayWheels: UIViewRepresentable {
    enum Column: Int, CaseIterable {
        case day, month, year
    }

    let draft: BirthdayComponents
    let years: ClosedRange<Int>
    /// Column widths at the reference size (Figma: Day 92, Month 100, Year 92), scaled.
    let scale: CGFloat
    let onSettle: (Column, Int?) -> Void
    /// `true` when a finger starts turning a wheel; `false` when it lets go of a wheel that is
    /// not coasting. A coasting wheel ends in `onSettle`.
    let onMotion: (Bool) -> Void

    /// Figma row pitch: previous, selected and next values 50 pt apart in a 150-pt window.
    static let rowHeight: CGFloat = 50
    /// How far each value is drawn above the middle of its picker row. Figma's text boxes
    /// (446, 492 and 546 in LAYOUT_SPEC.json) put the previous, selected and next glyph
    /// centres at 468.7, 516.0 and 568.7 on the approved board, 48 pt above and 52 pt below
    /// the selected one. UIPickerView spaces its rows symmetrically instead. With a single
    /// 4.5-pt lift, build 6ab6df01 measured 469.7, 517.0 and 565.7. The rows either side sit
    /// on the wheel's curve at about 0.8 of their height (15.3-pt digits against 18.7), so a
    /// lift moves them by 0.8 of itself. Hence 5.75 pt above the selection, 5.5 pt for the
    /// selected row, and 0.75 pt below it, at rest. While a wheel turns under a finger, every
    /// row takes the selected lift, so the value that settles in the lane does not jump.
    static let textLiftAbove: CGFloat = 5.75
    static let textLiftSelected: CGFloat = 5.5
    static let textLiftBelow: CGFloat = 0.75
    /// A neighbouring value as seen: UIPickerView fades rows outside its centre to about 37 %,
    /// so this renders as Figma's #616B6E there (measured on the iOS 26.5 simulator).
    static let neighbourColor = UIColor(red: 0xD2 / 255, green: 0xE6 / 255, blue: 0xEA / 255, alpha: 1)
    static let placeholderColor = UIColor(red: 0xA8 / 255, green: 0xB0 / 255, blue: 0xAD / 255, alpha: 1)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> BirthdayPickerView {
        let picker = BirthdayPickerView()
        picker.backgroundColor = .clear
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.accessibilityIdentifier = "birthday.wheels"
        // Observes drags without taking part in them: the wheels scroll exactly as before.
        let drag = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.wheelDragged(_:)))
        drag.cancelsTouchesInView = false
        drag.delaysTouchesBegan = false
        drag.delaysTouchesEnded = false
        drag.delegate = context.coordinator
        picker.addGestureRecognizer(drag)
        context.coordinator.apply(draft, to: picker)
        return picker
    }

    func updateUIView(_ picker: BirthdayPickerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(draft, to: picker)
    }

    @MainActor
    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate, UIPickerViewAccessibilityDelegate,
        UIGestureRecognizerDelegate {
        var parent: BirthdayWheels
        private var applied: BirthdayComponents?
        /// Unset wheels a finger has started turning: their rows are drawn from then on.
        private var revealed: Set<Int> = []
        /// Every row label handed to the picker, so a wheel's rows can be revealed in place,
        /// without reloading a wheel that is under a finger.
        private let rowLabels = NSHashTable<BirthdayRowLabel>.weakObjects()
        /// While a revealed wheel may still be snapping back, each scroll step re-runs the
        /// at-rest check (no timer), until every revealed wheel is concealed.
        private var restWatch: [NSKeyValueObservation] = []
        private let shortMonths: [String]
        private let fullMonths: [String]

        init(_ parent: BirthdayWheels) {
            self.parent = parent
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.calendar = Calendar(identifier: .gregorian)
            shortMonths = formatter.shortStandaloneMonthSymbols
            fullMonths = formatter.standaloneMonthSymbols
        }

        /// Moves wheels to the model's values only when the model changed from outside, so a
        /// wheel the user is turning is never pulled back mid-gesture.
        func apply(_ draft: BirthdayComponents, to picker: UIPickerView) {
            guard draft != applied else { return }
            applied = draft
            picker.setNeedsLayout()
            for column in Column.allCases {
                let row = self.row(for: value(of: column, in: draft), in: column)
                if picker.selectedRow(inComponent: column.rawValue) != row {
                    revealed.remove(column.rawValue)
                    picker.selectRow(row, inComponent: column.rawValue, animated: false)
                    picker.reloadComponent(column.rawValue)
                }
            }
        }

        // MARK: Rows and values

        private func value(of column: Column, in draft: BirthdayComponents) -> Int? {
            switch column {
            case .day: return draft.day
            case .month: return draft.month
            case .year: return draft.year
            }
        }

        /// Row 0 is "not set"; a value the wheel cannot show (e.g. a typed day 35) also
        /// shows as not set, while the typed value itself is kept in the model.
        private func row(for value: Int?, in column: Column) -> Int {
            guard let value else { return 0 }
            switch column {
            case .day: return (1...31).contains(value) ? value : 0
            case .month: return (1...12).contains(value) ? value : 0
            case .year: return parent.years.contains(value) ? value - parent.years.lowerBound + 1 : 0
            }
        }

        private func value(forRow row: Int, in column: Column) -> Int? {
            guard row > 0 else { return nil }
            switch column {
            case .day, .month: return row
            case .year: return parent.years.lowerBound + row - 1
            }
        }

        private func text(forRow row: Int, in column: Column) -> String {
            guard let value = value(forRow: row, in: column) else {
                switch column {
                case .day: return "DD"
                case .month: return "MMM"
                case .year: return "YYYY"
                }
            }
            switch column {
            case .day, .year: return String(value)
            case .month: return shortMonths.indices.contains(value - 1) ? shortMonths[value - 1] : String(value)
            }
        }

        private func spokenText(forRow row: Int, in column: Column) -> String {
            guard let value = value(forRow: row, in: column) else { return "Not set" }
            if column == .month, fullMonths.indices.contains(value - 1) {
                return fullMonths[value - 1]
            }
            return text(forRow: row, in: column)
        }

        // MARK: UIPickerViewDataSource

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            Column.allCases.count
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            switch Column(rawValue: component) {
            case .day: return 32
            case .month: return 13
            case .year: return parent.years.count + 1
            case .none: return 0
            }
        }

        // MARK: UIPickerViewDelegate

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            (component == Column.month.rawValue ? 100 : 92) * parent.scale
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            BirthdayWheels.rowHeight * parent.scale
        }

        func pickerView(
            _ pickerView: UIPickerView,
            viewForRow row: Int,
            forComponent component: Int,
            reusing view: UIView?
        ) -> UIView {
            let label = (view as? BirthdayRowLabel) ?? BirthdayRowLabel()
            rowLabels.add(label)
            let column = Column(rawValue: component) ?? .day
            let selectedRow = pickerView.selectedRow(inComponent: component)
            let isSelected = selectedRow == row
            label.component = component
            label.row = row
            let lift = revealed.contains(component) || row == selectedRow ? BirthdayWheels.textLiftSelected
                : row < selectedRow ? BirthdayWheels.textLiftAbove : BirthdayWheels.textLiftBelow
            label.lift = lift * parent.scale
            // At rest only the approved rows are drawn: the placeholder of an unset wheel, or
            // a set wheel's previous, selected and next values.
            let drawnAtRest = selectedRow == 0 ? row == 0 : abs(row - selectedRow) <= 1
            let hidden = !drawnAtRest && !revealed.contains(component)
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            label.text = text(forRow: row, in: column)
            label.accessibilityLabel = spokenText(forRow: row, in: column)
            if row == 0 {
                // Figma "Selected" placeholder: SemiBold 24, #A8B0AD.
                label.font = UIFont(name: Manrope.semiBold.rawValue, size: 24) ?? .systemFont(ofSize: 24, weight: .semibold)
                label.textColor = hidden ? .clear : BirthdayWheels.placeholderColor
            } else if isSelected {
                // Figma "Selected" value: SemiBold 30, white.
                label.font = UIFont(name: Manrope.semiBold.rawValue, size: 30) ?? .systemFont(ofSize: 30, weight: .semibold)
                label.textColor = .white
            } else {
                // Figma "Previous" / "Next": Regular 26, #616B6E as seen.
                label.font = UIFont(name: Manrope.regular.rawValue, size: 26) ?? .systemFont(ofSize: 26)
                label.textColor = hidden ? .clear : BirthdayWheels.neighbourColor
            }
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard let column = Column(rawValue: component) else { return }
            revealed.remove(component)
            stopWatchingIfConcealed()
            pickerView.reloadComponent(component)
            pickerView.setNeedsLayout()
            let settled = value(forRow: row, in: column)
            switch column {
            case .day: applied?.day = settled
            case .month: applied?.month = settled
            case .year: applied?.year = settled
            }
            parent.onSettle(column, settled)
        }

        // MARK: Drags

        @objc func wheelDragged(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                parent.onMotion(true)
                if let picker = recognizer.view as? UIPickerView {
                    reveal(wheelAt: recognizer.location(in: picker).x, in: picker)
                }
            case .ended, .cancelled, .failed:
                // A wheel still coasting reports through didSelectRow when it stops.
                if let picker = recognizer.view, !Self.isCoasting(picker) {
                    parent.onMotion(false)
                }
                // A wheel that settles back on its own row may not report didSelectRow. Once the
                // lift-off has been handled (the next main-actor turn), a revealed wheel resting
                // exactly on its selected row goes back to its approved rows.
                if let picker = recognizer.view as? UIPickerView {
                    watchUntilConcealed(picker)
                    Task { [weak self, weak picker] in
                        guard let self, let picker else { return }
                        self.concealWheelsAtRest(in: picker)
                    }
                }
            default:
                break
            }
        }

        /// Draws every row of the wheel under the finger, in place: a reload would pull the
        /// wheel back under the finger. A drag that starts in a gap or margin reveals the
        /// nearest wheel, never the others. Every row of a revealed wheel takes the selected
        /// lift while it moves.
        private func reveal(wheelAt x: CGFloat, in picker: UIPickerView) {
            var nearest: (component: Int, distance: CGFloat)?
            for component in 0..<picker.numberOfComponents {
                guard let row = picker.view(forRow: picker.selectedRow(inComponent: component), forComponent: component) else {
                    continue
                }
                let frame = row.convert(row.bounds, to: picker)
                let distance = max(frame.minX - x, x - frame.maxX, 0)
                if distance < (nearest?.distance ?? .infinity) {
                    nearest = (component, distance)
                }
            }
            guard let wheel = nearest?.component else { return }
            revealed.insert(wheel)
            let selectedRow = picker.selectedRow(inComponent: wheel)
            for label in rowLabels.allObjects where label.component == wheel {
                label.lift = BirthdayWheels.textLiftSelected * parent.scale
                guard label.row != selectedRow else { continue }
                label.textColor = label.row == 0 ? BirthdayWheels.placeholderColor : BirthdayWheels.neighbourColor
            }
        }

        /// Returns each revealed wheel that rests exactly on its selected row, with nothing
        /// tracking, dragging or coasting, to its approved rows. A wheel still on its way to a
        /// row is left alone: it reports through didSelectRow.
        private func concealWheelsAtRest(in picker: UIPickerView) {
            defer { stopWatchingIfConcealed() }
            guard !Self.isMoving(picker) else { return }
            for component in revealed {
                guard let row = picker.view(forRow: picker.selectedRow(inComponent: component), forComponent: component) else {
                    continue
                }
                let centre = row.convert(CGPoint(x: row.bounds.midX, y: row.bounds.midY), to: picker).y
                guard abs(centre - picker.bounds.midY) < 0.5 else { continue }
                revealed.remove(component)
                picker.reloadComponent(component)
            }
        }

        /// Re-runs the at-rest check one main-actor turn after each scroll step of the wheels
        /// (so UIKit has finished that step), until every revealed wheel has been concealed.
        private func watchUntilConcealed(_ picker: UIPickerView) {
            guard restWatch.isEmpty, !revealed.isEmpty else { return }
            restWatch = Self.scrollViews(in: picker).map { scroll in
                scroll.observe(\.contentOffset) { [weak self, weak picker] _, _ in
                    Task { @MainActor [weak self, weak picker] in
                        guard let self, let picker else { return }
                        self.concealWheelsAtRest(in: picker)
                    }
                }
            }
        }

        private func stopWatchingIfConcealed() {
            guard revealed.isEmpty, !restWatch.isEmpty else { return }
            restWatch.forEach { $0.invalidate() }
            restWatch = []
        }

        private static func scrollViews(in view: UIView) -> [UIScrollView] {
            if let scroll = view as? UIScrollView {
                return [scroll]
            }
            return view.subviews.flatMap { scrollViews(in: $0) }
        }

        private static func isMoving(_ view: UIView) -> Bool {
            if let scroll = view as? UIScrollView, scroll.isTracking || scroll.isDragging || scroll.isDecelerating {
                return true
            }
            return view.subviews.contains { isMoving($0) }
        }

        private static func isCoasting(_ view: UIView) -> Bool {
            if let scroll = view as? UIScrollView, scroll.isDecelerating {
                return true
            }
            return view.subviews.contains { isCoasting($0) }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // MARK: UIPickerViewAccessibilityDelegate

        func pickerView(_ pickerView: UIPickerView, accessibilityLabelForComponent component: Int) -> String? {
            switch Column(rawValue: component) {
            case .day: return "Day"
            case .month: return "Month"
            case .year: return "Year"
            case .none: return nil
            }
        }
    }
}

/// `UIPickerView` without UIKit's own selection bar: the approved lane (#242A2B at 76%,
/// 308 × 58, radius 8) is drawn behind the wheels instead, so there is exactly one. On iOS 26
/// the bar is a glass capsule above the rows, a little taller than a row, spanning every
/// wheel. It is found by shape and content, never by a private class name: a view that spans
/// most of the width, is at most 60 % of the height, and holds no rows (no scroll view, label
/// or image anywhere inside it). The choice is undone and made again on every layout pass, so a
/// view judged too early (before its rows loaded) is shown again as soon as it holds rows.
final class BirthdayPickerView: UIPickerView {
    private let hiddenBars = NSHashTable<UIView>.weakObjects()

    override func layoutSubviews() {
        super.layoutSubviews()
        for view in hiddenBars.allObjects {
            view.alpha = 1
        }
        hiddenBars.removeAllObjects()
        hideSelectionBar(in: self)
    }

    private func hideSelectionBar(in container: UIView) {
        for view in container.subviews where !(view is UIScrollView) && !(view is UILabel) {
            let size = view.bounds.size
            guard size.width >= bounds.width * 0.6, size.height > 0 else { continue }
            if size.height <= bounds.height * 0.6, !Self.holdsRows(view) {
                view.alpha = 0
                hiddenBars.add(view)
            } else {
                hideSelectionBar(in: view)
            }
        }
    }

    /// Wheel rows live in scroll views and are drawn as labels (or shown as images of them).
    private static func holdsRows(_ view: UIView) -> Bool {
        view.subviews.contains { $0 is UIScrollView || $0 is UILabel || $0 is UIImageView || holdsRows($0) }
    }
}

/// A wheel row's label, drawn `lift` points above the middle of its row.
final class BirthdayRowLabel: UILabel {
    var lift: CGFloat = 0 {
        didSet {
            if lift != oldValue { setNeedsDisplay() }
        }
    }
    var component = 0
    var row = 0

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.offsetBy(dx: 0, dy: -lift))
    }
}
