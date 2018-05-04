pragma solidity ^0.4.0;

contract Repository {

    struct TeamMember {
        address wallet;
        uint16 percent;
    }

    TeamMember[] team;
}