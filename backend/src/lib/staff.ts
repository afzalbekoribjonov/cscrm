/**
 * Xodimning Firebase UID'i.
 *
 * Barqaror bo'lishi SHART: kirishda token shu UID bilan yaratiladi,
 * xodim o'chirilganda esa aynan shu UID'ning sessiyalari bekor
 * qilinadi. Ikki joyda ikki xil yasalsa, bekor qilish boshqa
 * (mavjud bo'lmagan) hisobga ketib, xodim ishlashda davom etardi.
 */
export function staffUid(tenantId: string, employeeId: string): string {
  return `staff_${tenantId}_${employeeId}`;
}
