import type { RenderParameters } from './rouletteRenderer';
import type { Rect } from './types/rect.type';
import type { MouseEventArgs, UIObject } from './UIObject';

export class FastForwader implements UIObject {
  private bound: Rect = {
    x: 0,
    y: 0,
    w: 0,
    h: 0,
  };
  private icon: HTMLImageElement;

  constructor() {
    this.icon = new Image();
    this.icon.src = new URL('../assets/images/ff.svg', import.meta.url).toString();
  }

  private isEnabled: boolean = false;

  public get speed(): number {
    return this.isEnabled ? 2 : 1;
  }

  update(_deltaTime: number): void {}

  render(ctx: CanvasRenderingContext2D, _params: RenderParameters, width: number, height: number): void {
    this.bound.w = width / 2;
    this.bound.h = height / 2;
    this.bound.x = this.bound.w / 2;
    this.bound.y = this.bound.h / 2;

    const centerX = this.bound.x + this.bound.w / 2;
    const centerY = this.bound.y + this.bound.h / 2;

    if (this.isEnabled) {
      ctx.save();
      ctx.strokeStyle = 'white';
      ctx.globalAlpha = 0.5;
      ctx.drawImage(this.icon, centerX - 100, centerY - 100, 200, 200);
      ctx.restore();
    }
  }

  getBoundingBox(): Rect | null {
    return this.bound;
  }

  // 화면을 누르고 있는 동안 2배속으로 가던 기능은 배속 버튼으로 대체했다.
  // 둘을 같이 두면 배속이 곱해져(4배 + 홀드 = 8배) 예상과 다르게 빨라진다.
  // 되살리려면 아래 두 핸들러의 주석을 풀면 된다.
  //
  // onMouseDown?(_e?: MouseEventArgs): void {
  //   this.isEnabled = true;
  // }
  //
  // onMouseUp?(_e?: MouseEventArgs): void {
  //   this.isEnabled = false;
  // }
}
