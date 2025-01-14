// SPDX-License-Identifier: UNLICENSED
pragma solidity <=0.8.25;

import "./Issuers.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract Certificates {
    struct Certificate {
        address holder;
        address issuer;
        string fileUrl;
        uint16 score;
        uint256 issueDate;
        uint256 expireDate;
        bool isRevoked;
    }

    Issuers private issuers;
    address private revocationConsensusContract;

    mapping(address => mapping(bytes32 => Certificate)) public certificates;
    mapping(address => uint256) public certificatesCount;

    constructor(address _issuerContractAddress) payable {
        issuers = Issuers(_issuerContractAddress);
    }

    event CertificateIssued(
        address indexed _holder,
        address indexed _issuer,
        string _fileUrl,
        uint256 _issueDate,
        uint256 _expireDate,
        bytes32 _certificateHash
    );

    event RevokedCertificate(
        address indexed _issuer,
        address indexed _holder,
        bytes32 _certificateHash
    );

    modifier onlyIssuer() {
        require(
            issuers.authorizedIssuers(msg.sender),
            "Only authorized issuers can call this function"
        );
        _;
    }

    modifier onlyCertificateIssuer(address _holder, bytes32 _certificateHash) {
        require(
            certificates[_holder][_certificateHash].issuer == msg.sender,
            "Only the issuer of this certificate can call this function"
        );
        _;
    }

    modifier onlyRevocationConsensus() {
        require(
            msg.sender == revocationConsensusContract,
            "Only the revocation consensus contract can call this function"
        );
        _;
    }

    function setRevocationConsensusContract(
        address _revocationConsensusContract
    ) external onlyIssuer {
        revocationConsensusContract = _revocationConsensusContract;
    }

    function issueCertificate(
        address _holder,
        string memory _fileUrl,
        uint16 _score,
        uint256 _expireDate
    ) public onlyIssuer returns (bytes32) {
        bytes32 certificateHash = keccak256(
            abi.encode(_holder, _fileUrl, _score, block.timestamp, _expireDate)
        );

        require(
            certificates[_holder][certificateHash].holder == address(0),
            "Certificate already exists"
        );

        require(
            !certificates[_holder][certificateHash].isRevoked,
            "Certificate has been revoked"
        );

        certificates[_holder][certificateHash] = Certificate(
            _holder,
            msg.sender,
            _fileUrl,
            _score,
            block.timestamp,
            _expireDate,
            false
        );

        certificatesCount[_holder]++;

        emit CertificateIssued(
            _holder,
            msg.sender,
            _fileUrl,
            block.timestamp,
            _expireDate,
            certificateHash
        );

        return certificateHash;
    }

    function revokeCertificate(
        address _holder,
        bytes32 _certificateHash
    ) external onlyRevocationConsensus returns (bool) {
        require(
            certificates[_holder][_certificateHash].holder != address(0),
            "Certificate does not exist"
        );

        certificates[_holder][_certificateHash].isRevoked = true;
        certificatesCount[_holder]--;

        emit RevokedCertificate(msg.sender, _holder, _certificateHash);

        return true;
    }

    function verifyCertificate(
        address _holder,
        bytes32 _certificateHash
    ) external view returns (bool) {
        return
            !certificates[_holder][_certificateHash].isRevoked &&
            certificates[_holder][_certificateHash].issueDate > 0;
    }

    function getCertificateByHash(
        address _holder,
        bytes32 _certificateHash
    ) external view returns (Certificate memory) {
        return certificates[_holder][_certificateHash];
    }

    function getCertificatesCount(
        address _holder
    ) external view returns (uint256) {
        return certificatesCount[_holder];
    }
}
