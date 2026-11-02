import './localization';
import options from './options';
import { Roulette } from './roulette';

const roulette = new Roulette();

(window as any).roulette = roulette;
// 듀얼 모드가 두 번째 판을 띄울 때 쓴다. 미리 만들면 wasm 과 캔버스를 하나 더 들고 있게 된다.
(window as any).createRoulette = () => new Roulette();
(window as any).options = options;
