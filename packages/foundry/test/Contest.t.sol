// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Contest} from "../src/Contest.sol";
import {DeployContest} from "../script/DeployContest.s.sol";
import {Constants} from "./Constants.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ContestTest is Test {
    Contest public contest;
    DeployContest public deployer;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");

    function setUp() public {
        deployer = new DeployContest();
        contest = deployer.run(
            Constants.CONTEST_TITLE,
            Constants.CONTEST_DESCRIPTION,
            block.timestamp + 1 days,
            block.timestamp + 2 days,
            block.timestamp + 3 days,
            block.timestamp + 4 days,
            Constants.CONTEST_MAX_ENTRIES_PER_PARTICIPANT,
            Constants.CONTEST_MAX_TOTAL_ENTRIES
        );
    }

    function testContestInitialization() public view {
        // Verify that the contract's state is initialized correctly
        assertEq(contest.s_title(), Constants.CONTEST_TITLE, "Contest title should match");
        assertEq(contest.s_description(), Constants.CONTEST_DESCRIPTION, "Contest description should match");
        assertEq(contest.s_organizer(), msg.sender, "Organizer address should match");
        assertEq(contest.s_isCanceled(), false, "Contest should not be canceled initially");
        assertEq(contest.s_maxEntriesPerParticipant(), Constants.CONTEST_MAX_ENTRIES_PER_PARTICIPANT);
        assertEq(contest.s_maxTotalEntries(), Constants.CONTEST_MAX_TOTAL_ENTRIES);
    }

    function testGetContestStatusInactive() public {
        // Fast forward to a time before the entry start time
        vm.warp(block.timestamp + 0.5 days);
        Contest.ContestStatus status = contest.getContestStatus();
        assertEq(
            uint256(status), uint256(Contest.ContestStatus.Inactive), "Contest should be inactive before entry starts"
        );
    }

    function testGetContestStatusOpenForParticipants() public {
        // Fast forward to a time during the entry period
        vm.warp(block.timestamp + 1 days);
        Contest.ContestStatus status = contest.getContestStatus();
        assertEq(
            uint256(status),
            uint256(Contest.ContestStatus.OpenForParticipants),
            "Contest should be open for participants during the entry period"
        );
    }

    function testGetContestStatusVotingStarted() public {
        // Fast forward to a time during the voting period
        vm.warp(block.timestamp + 3.5 days);
        Contest.ContestStatus status = contest.getContestStatus();
        assertEq(
            uint256(status), uint256(Contest.ContestStatus.VotingStarted), "Contest should be in the voting period"
        );
    }

    function testGetContestStatusEnded() public {
        // Fast forward to a time after the voting period ends
        vm.warp(block.timestamp + 4.5 days);
        Contest.ContestStatus status = contest.getContestStatus();
        assertEq(
            uint256(status), uint256(Contest.ContestStatus.Ended), "Contest should be ended after the voting period"
        );
    }

    function testGetContestStatusCanceled() public {
        // Simulate the cancellation of the contest
        vm.prank(msg.sender);
        contest.cancelContest();
        Contest.ContestStatus status = contest.getContestStatus();
        assertEq(uint256(status), uint256(Contest.ContestStatus.Canceled), "Contest should be canceled");
    }

    function testCancelContestRevertIfNotOrganizerCancels() public {
        // Attempt to cancel the contest from a different address

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        vm.startPrank(alice);
        contest.cancelContest(); // Call without setting msg.sender to ORGANIZER
        vm.stopPrank();
    }

    function testSubmitEntrySuccessfully() public {
        vm.warp(block.timestamp + 1.5 days);

        // Simulate entry submission by the participant
        vm.prank(alice);
        uint256 entryId = contest.submitEntry("My first entry");

        // Verify the entry is recorded correctly
        Contest.ParticipantEntry memory entry = contest.getEntry(entryId);
        assertEq(entry.content, "My first entry", "Entry content should match");
        assertEq(contest.s_participantEntryCount(alice), 1, "Participant entry count should be 1");
        assertEq(contest.s_allEntryIds(0), entryId);
    }

    function testRevertIfNotOpenForEntries() public {
        // Attempt to submit an entry before the entry period starts
        vm.warp(block.timestamp - 1);
        vm.prank(alice);

        // Expect revert due to not being open for entries
        vm.expectRevert(Contest.Contest__NotOpenForParticipants.selector);
        contest.submitEntry("This entry should not be accepted");
    }

    function testRevertIfEntryAlreadyExists() public {
        // Fast forward time to during the entry period
        vm.warp(block.timestamp + 1.5 days);

        // Simulate a participant submitting an entry
        vm.prank(alice);
        contest.submitEntry("Duplicate entry");

        // Attempt to submit the same entry again
        vm.expectRevert(Contest.Contest__EntryAlreadyExists.selector);
        vm.prank(alice);
        contest.submitEntry("Duplicate entry");
    }

    function testRevertIfExceededParticipantEntryLimit() public {
        // Fast forward time to during the entry period
        vm.warp(block.timestamp + 1.5 days);

        vm.startPrank(alice);
        for (uint256 i = 0; i < Constants.CONTEST_MAX_ENTRIES_PER_PARTICIPANT; i++) {
            contest.submitEntry(string(abi.encodePacked("Entry ", i)));
        }
        vm.stopPrank();
        // Attempt to submit another entry, which should exceed the limit
        vm.expectRevert(
            abi.encodeWithSelector(
                Contest.Contest__ExceededEntryLimit.selector, Constants.CONTEST_MAX_ENTRIES_PER_PARTICIPANT
            )
        );

        vm.startPrank(alice);
        contest.submitEntry("This entry should exceed the limit");
        vm.stopPrank();
    }

    function testRevertIfExceededTotalEntryLimit() public {
        // Fast forward time to during the entry period
        vm.warp(block.timestamp + 1.5 days);

        // Simulate entry submissions by different participants until total entry limit is reached
        for (uint256 i = 0; i < Constants.CONTEST_MAX_TOTAL_ENTRIES; i++) {
            address newParticipant = address(uint160(i + 1)); // Create unique participant addresses
            vm.prank(newParticipant);
            contest.submitEntry(string(abi.encodePacked("Entry by ", newParticipant)));
        }

        // Attempt to submit an entry which should exceed the total entry limit
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Contest.Contest__ExceededTotalMaxEntryLimit.selector, Constants.CONTEST_MAX_TOTAL_ENTRIES
            )
        );
        contest.submitEntry("This entry should exceed the total limit");
    }

    function testDeleteEntrySuccessfully() public {
        vm.warp(block.timestamp + 1.5 days);

        vm.startPrank(alice);
        contest.submitEntry("This entry will be deleted");
        vm.stopPrank();

        uint256 entryIdToDelete = contest.s_allEntryIds(0);

        Contest.ParticipantEntry memory entry = contest.getEntry(entryIdToDelete);
        assertTrue(entry.exists, "Entry should exist before deletion");

        // As the contract owner, delete the entry.
        vm.startPrank(msg.sender);
        contest.deleteEntry(entryIdToDelete);
        vm.stopPrank();

        // Verify that the entry no longer exists.
        entry = contest.getEntry(entryIdToDelete);
        assertFalse(entry.exists, "Entry should not exist after deletion");

        // Check that the entry ID is added to the deleted entries list.
        uint256[] memory deletedEntryIds = contest.getDeletedEntryIDs();
        assertEq(deletedEntryIds.length, 1, "There should be one deleted entry ID");
        assertEq(deletedEntryIds[0], entryIdToDelete, "The deleted entry ID should match the entry that was deleted");
    }

    function testDeleteEntryRevertIfNotOwner() public {
        vm.warp(block.timestamp + 1.5 days);

        vm.startPrank(alice);
        contest.submitEntry("This entry will be deleted");
        vm.stopPrank();

        uint256 entryIdToDelete = contest.getAllEntryIds()[0];

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vm.startPrank(bob);
        contest.deleteEntry(entryIdToDelete);
        vm.stopPrank();
    }

    function testRevertIfContestEndedOrCanceled() public {
        // End the contest by fast-forwarding past the voting end time.
        vm.warp(block.timestamp + 1.5 days);

        vm.startPrank(alice);
        contest.submitEntry("This entry will be deleted");
        vm.stopPrank();
        uint256 entryIdToDelete = contest.getAllEntryIds()[0];

        // Attempt to delete the entry after the contest has ended.
        vm.warp(block.timestamp + 100 days);

        vm.expectRevert(Contest.Contest__CannotDeleteEntryAfterContestEndedOrCanceled.selector);
        vm.startPrank(msg.sender);
        contest.deleteEntry(entryIdToDelete);
        vm.stopPrank();

        // Alternatively, cancel the contest and try deleting again.
        vm.warp(block.timestamp + 1.5 days); // Reset to a time during the entry period.

        vm.startPrank(msg.sender);
        contest.cancelContest();
        vm.stopPrank();

        vm.expectRevert(Contest.Contest__CannotDeleteEntryAfterContestEndedOrCanceled.selector);
        vm.startPrank(msg.sender);
        contest.deleteEntry(entryIdToDelete);
        vm.stopPrank();
    }
}