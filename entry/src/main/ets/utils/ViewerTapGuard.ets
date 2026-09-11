export const VIEWER_TAP_DISTANCE: number = 8;

// A completed drag must stay disqualified even if it ends at its starting point.
// Keep press duration separate from the delay used to distinguish a double tap.
export class ViewerTapGuard {
  private pointers: Set<number> = new Set<number>();
  private primary: number = -1;
  private startX: number = 0;
  private startY: number = 0;
  private startedAt: number = 0;
  private eligible: boolean = false;
  private released: boolean = false;

  down(id: number, x: number, y: number, time: number): void {
    if (this.pointers.size === 0) {
      this.primary = id;
      this.startX = x;
      this.startY = y;
      this.startedAt = time;
      this.eligible = true;
      this.released = false;
    } else {
      this.invalidate();
    }
    this.pointers.add(id);
  }

  move(id: number, x: number, y: number): void {
    if (id !== this.primary || Math.hypot(x - this.startX, y - this.startY) > VIEWER_TAP_DISTANCE) {
      this.invalidate();
    }
  }

  up(id: number, x: number, y: number, time: number): void {
    this.move(id, x, y);
    if (!this.pointers.has(id) || time - this.startedAt > 300) { this.invalidate(); }
    this.pointers.delete(id);
    this.released = this.pointers.size === 0;
  }

  invalidate(): void { this.eligible = false; }

  cancel(): void {
    this.invalidate();
    this.pointers.clear();
    this.released = false;
  }

  consume(): boolean {
    const allowed = this.eligible && this.released && this.pointers.size === 0;
    this.invalidate();
    return allowed;
  }
}
