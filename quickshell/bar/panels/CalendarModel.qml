import QtQuick

QtObject {
  id: root
  property date currentDate: new Date()
  property date selectedDate: new Date()
  property int year: currentDate.getFullYear()
  property int month: currentDate.getMonth()

  readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
  readonly property int startWeekday: {
    const d = new Date(year, month, 1).getDay();
    return d === 0 ? 6 : d - 1;
  }
  readonly property int totalCells: Math.ceil((startWeekday + daysInMonth) / 7) * 7
  readonly property var today: new Date()

  readonly property var dayCells: {
    const cells = [];
    const now = new Date();
    const todayDate = now.getDate();
    const todayMonth = now.getMonth();
    const todayYear = now.getFullYear();

    for (let i = 0; i < totalCells; i++) {
      const dayNum = i - startWeekday + 1;
      cells.push({
        day: (dayNum >= 1 && dayNum <= daysInMonth) ? dayNum : -1,
        today: dayNum === todayDate && month === todayMonth && year === todayYear,
        current: dayNum === selectedDate.getDate() && month === selectedDate.getMonth() && year === selectedDate.getFullYear()
      });
    }
    return cells;
  }

  onCurrentDateChanged: {
    year = currentDate.getFullYear();
    month = currentDate.getMonth();
  }
}
