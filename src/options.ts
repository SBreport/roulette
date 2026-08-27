class Options {
  useSkills: boolean = true;
  winningRank: number = 0;
  // 당첨 인원. winningRank 를 마지막으로 하는 연속 구간의 길이.
  winnerCount: number = 1;
  autoRecording: boolean = true;
}

const options = new Options();
export default options;
