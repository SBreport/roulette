import { fontFamily } from './data/constants';
import type { Marble } from './marble';
import type { RenderParameters } from './rouletteRenderer';
import type { Rect } from './types/rect.type';
import type { MouseEventArgs, UIObject } from './UIObject';
import { bound } from './utils/bound.decorator';

export class RankRenderer implements UIObject {
  private _currentY = 0;
  private _targetY = 0;
  private fontHeight = 16;
  private _userMoved = 0;
  private _currentWinner = -1;
  private maxY = 0;
  private winners: Marble[] = [];
  private marbles: Marble[] = [];
  private winnerRank: number = -1;
  private winnerCount: number = 1;
  private messageHandler?: (msg: string) => void;

  @bound
  onWheel(e: WheelEvent) {
    this._targetY += e.deltaY;
    if (this._targetY > this.maxY) {
      this._targetY = this.maxY;
    }
    this._userMoved = 2000;
  }

  // 당첨 구간(마지막 순위에서 인원수만큼 거슬러 올라간 연속 구간)에 드는 순위인가.
  private isWinningRank(rank: number, winnerRank = this.winnerRank, winnerCount = this.winnerCount) {
    return rank <= winnerRank && rank > winnerRank - winnerCount;
  }

  @bound
  onDblClick(e?: MouseEventArgs) {
    if (e) {
      if (navigator.clipboard) {
        const tsv: string[] = [];
        let rank = 0;
        tsv.push(
          ...[...this.winners, ...this.marbles].map((m) => {
            rank++;
            return [rank.toString(), m.name, this.isWinningRank(rank - 1) ? '☆' : ''].join('\t');
          })
        );

        tsv.unshift(['Rank', 'Name', 'Winner'].join('\t'));

        navigator.clipboard.writeText(tsv.join('\n')).then(() => {
          if (this.messageHandler) {
            this.messageHandler('The result has been copied');
          }
        });
      }
    }
  }

  onMessage(func: (msg: string) => void) {
    this.messageHandler = func;
  }

  render(
    ctx: CanvasRenderingContext2D,
    { winners, marbles, winnerRank, winnerCount, theme, uiScale }: RenderParameters,
    width: number,
    height: number
  ) {
    // 폰에서는 씬이 축소돼 붙으므로 글자와 줄 간격을 배율만큼 키운다.
    const scale = uiScale || 1;
    this.fontHeight = 16 * scale;
    const startX = width - 5;
    const startY = Math.max(-this.fontHeight, this._currentY - height / 2);
    this.maxY = Math.max(0, (marbles.length + winners.length) * this.fontHeight + this.fontHeight);
    this._currentWinner = winners.length;

    this.winners = winners;
    this.marbles = marbles;
    this.winnerRank = winnerRank;
    this.winnerCount = winnerCount;

    ctx.save();
    ctx.textAlign = 'right';
    ctx.font = `${10 * scale}pt ${fontFamily}`;
    ctx.fillStyle = '#666';
    ctx.fillText(`${winners.length} / ${winners.length + marbles.length}`, width - 5, this.fontHeight);

    ctx.beginPath();
    ctx.rect(width - 150 * scale, this.fontHeight + 2, width, this.maxY);
    ctx.clip();

    ctx.translate(0, -startY);
    ctx.font = `bold ${11 * scale}pt ${fontFamily}`;
    if (theme.rankStroke) {
      ctx.lineWidth = 2;
      ctx.strokeStyle = theme.rankStroke;
    }
    winners.forEach((marble: { hue: number; name: string }, rank: number) => {
      const y = rank * this.fontHeight;
      if (y >= startY && y <= startY + ctx.canvas.height) {
        ctx.fillStyle = `hsl(${marble.hue} 100% ${theme.marbleLightness}`;
        const mark = this.isWinningRank(rank, winnerRank, winnerCount) ? '☆' : '\u2714';
        ctx.strokeText(`${mark} ${marble.name} #${rank + 1}`, startX, 20 * scale + y);
        ctx.fillText(`${mark} ${marble.name} #${rank + 1}`, startX, 20 * scale + y);
      }
    });
    ctx.font = `${10 * scale}pt ${fontFamily}`;
    marbles.forEach((marble: { hue: number; name: string }, rank: number) => {
      const y = (rank + winners.length) * this.fontHeight;
      if (y >= startY && y <= startY + ctx.canvas.height) {
        // 아직 통과하지 않았어도 당첨 구간에 드는 순위면 별표를 붙인다.
        const overallRank = rank + winners.length;
        const mark = this.isWinningRank(overallRank, winnerRank, winnerCount) ? '☆ ' : '';
        ctx.fillStyle = `hsl(${marble.hue} 100% ${theme.marbleLightness}`;
        ctx.strokeText(`${mark}${marble.name} #${overallRank + 1}`, startX, 20 * scale + y);
        ctx.fillText(`${mark}${marble.name} #${overallRank + 1}`, startX, 20 * scale + y);
      }
    });
    ctx.restore();
  }

  update(deltaTime: number) {
    if (this._currentWinner === -1) {
      return;
    }
    if (this._userMoved > 0) {
      this._userMoved -= deltaTime;
    } else {
      this._targetY = this._currentWinner * this.fontHeight + this.fontHeight;
    }
    if (this._currentY !== this._targetY) {
      this._currentY += (this._targetY - this._currentY) * (deltaTime / 250);
    }
    if (Math.abs(this._currentY - this._targetY) < 1) {
      this._currentY = this._targetY;
    }
  }

  getBoundingBox(): Rect | null {
    return null;
  }
}
