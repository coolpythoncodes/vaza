import { ContestStatus } from "@/lib/utils";
import Countdown from "react-countdown";

type Props = {
  entryStartTime: bigint;
  entryEndTime: bigint;
  votingStartTime: bigint;
  votingEndTime: bigint;
  status: number;
};

// @ts-expect-error unknown error
const renderer = ({ days, hours, minutes, completed }: unknown) => {
  if (completed) {
    return <span>Time is up!</span>;
  } else {
    return (
      <span>
        {days ? `${days} days ` : null}
        {hours ? `${hours} hrs ` : null}
        {minutes ? `${minutes} mins ` : null}
      </span>
    );
  }
};

const ContestDuration = ({
  entryStartTime,
  entryEndTime,
  votingStartTime,
  votingEndTime,
  status,
}: Props) => {
  const entryStart = new Date(Number(entryStartTime) * 1000);
  const entryEnd = new Date(Number(entryEndTime) * 1000);
  const votingStart = new Date(Number(votingStartTime) * 1000);
  const votingEnd = new Date(Number(votingEndTime) * 1000);

  const getContestDurationMessage = () => {
    switch (status) {
      case ContestStatus.Inactive:
        return (
          <>
            <p>Contest is open in:</p>
            <Countdown date={entryStart} renderer={renderer} />
          </>
        );
      case ContestStatus.OpenForParticipants:
        return (
          <>
            <p>Contest participation ends in:</p>
            <Countdown date={entryEnd} renderer={renderer} />
            <p>Voting starts in:</p>
            <Countdown date={votingStart} renderer={renderer} />
          </>
        );
      case ContestStatus.VotingStarted:
        return (
          <>
            <p>Voting ends in:</p>
            <Countdown date={votingEnd} renderer={renderer} />
          </>
        );
      case ContestStatus.Canceled:
        return <p>Contest has been canceled.</p>;
      case ContestStatus.Ended:
        return <p>Contest has ended.</p>;
      default:
        return "";
    }
  };
  return (
    <div className="flex items-center gap-x-1 text-xs text-[#D7C5FF]">
      {getContestDurationMessage()}
    </div>
  );
};

export default ContestDuration;