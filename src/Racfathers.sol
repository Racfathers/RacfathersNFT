// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract RacfathersNFT is ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {

    error ClaimPeriodExpired();
    error RewardAlreadyClaimed();
    error ShouldOwnToken();
    error InvalidMerkleProof();
    error MaxSupplyReached();
    error InsufficientBalance();
    error TokenNotFound();
    error WithdrawFailed();

    using Strings for uint256;
    using Strings for address;

    uint256 public constant MAX_SUPPLY = 1728;
    uint256 public constant MINT_PRICE = 0.11 ether;
    uint256 public max;

    string public baseUri;
    string public baseExtension = ".json";

    bytes32 public merkleRoot_Weekly;
    bytes32 public merkleRoot_Monthly;

    uint256 public weeklyDistributionTime;
    uint256 public monthlyDistributionTime;

    mapping(address => mapping(uint256 => bool)) public weeklyClaimedRewards;
    mapping(address => mapping(uint256 => bool)) public monthlyClaimedRewards;
    mapping(address => uint256) totalMinted;
    
    event Minted(address indexed owner, uint256 tokenId);
    event WeeklyRewardClaimed(
        address indexed owner,
        uint256 amount,
        uint256 weekIndex
    );
    event MonthlyRewardClaimed(
        address indexed owner,
        uint256 amount,
        uint256 monthIndex
    );
    event WeeklyMerkleRootUpdated(bytes32 merkleRoot_Weekly);
    event MonthlyMerkleRootUpdated(bytes32 merkleRoot_Monthly);
    event ContractPaused(bool paused);
    event WeeklyRewardsDistributed(uint256 week, uint256 time);
    event MonthlyRewardsDistributed(uint256 month, uint256 time);
    event ReturnData(bytes32 data);
    event Withdrawn(address owner, uint256 amount);

    constructor()
        ERC721("RacfathersNFT", "RACF")
        Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
    {
        _pause();
    }

    modifier onlyUnpaused() {
        require(!paused(), "Contract is paused");
        _;
    }

    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(true);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractPaused(false);
    }

    function updateWeeklyMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot_Weekly = _merkleRoot;
        emit WeeklyMerkleRootUpdated(_merkleRoot);
    }

    function updateMonthlyMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot_Monthly = _merkleRoot;
        emit MonthlyMerkleRootUpdated(_merkleRoot);
    }

    function distributeWeeklyRewards(uint256 week, bytes32 _merkleRoot)
        external
        onlyOwner
    {
        weeklyDistributionTime = block.timestamp;
        merkleRoot_Weekly = _merkleRoot;
        emit WeeklyRewardsDistributed(week, block.timestamp);
        emit WeeklyMerkleRootUpdated(_merkleRoot);
    }

    function distributeMonthlyRewards(uint256 month, bytes32 _merkleRoot)
        external
        onlyOwner
    {
        monthlyDistributionTime = block.timestamp;
        merkleRoot_Monthly = _merkleRoot;
        emit MonthlyRewardsDistributed(month, block.timestamp);
        emit MonthlyMerkleRootUpdated(_merkleRoot);
    }
    function setBaseURI(string memory _uri) external onlyOwner {
        baseUri = _uri;
    }
    
    function claimWeeklyReward(
        uint256 index,
        uint256 amount,
        uint256 weekIndex,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external onlyUnpaused nonReentrant {
        if (block.timestamp > weeklyDistributionTime + 2 days) {
            revert ClaimPeriodExpired();
        }

        if (weeklyClaimedRewards[msg.sender][weekIndex]) {
            revert RewardAlreadyClaimed();
        }
         if (
            ownerOf(tokenId) != msg.sender
        ){
            revert ShouldOwnToken();
        }
        bytes32 leaf = keccak256(
            abi.encodePacked(index, msg.sender, amount, weekIndex, tokenId)
        );

        if (MerkleProof.verify(merkleProof, merkleRoot_Weekly, leaf) == false) {
            revert InvalidMerkleProof();
        }
        weeklyClaimedRewards[msg.sender][weekIndex] = true;
        payable(msg.sender).transfer(amount);
        emit WeeklyRewardClaimed(msg.sender, amount, weekIndex);
    }

    function claimMonthlyReward(
        uint256 index,
        uint256 amount,
        uint256 monthIndex,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external onlyUnpaused nonReentrant {

        if (block.timestamp > monthlyDistributionTime + 2 days) {
            revert ClaimPeriodExpired();
        }
        if (monthlyClaimedRewards[msg.sender][monthIndex]) {
            revert RewardAlreadyClaimed();
        }
        if (
            ownerOf(tokenId) != msg.sender
        ){
            revert ShouldOwnToken();
        }
        bytes32 leaf = keccak256(
            abi.encodePacked(index, msg.sender, amount, monthIndex, tokenId)
        );
        if (
            MerkleProof.verify(merkleProof, merkleRoot_Monthly, leaf) == false
        ) {
            revert InvalidMerkleProof();
        }
        monthlyClaimedRewards[msg.sender][monthIndex] = true;
        payable(msg.sender).transfer(amount);
        emit MonthlyRewardClaimed(msg.sender, amount, monthIndex);
    }


    function mintNFT(address to) external payable onlyUnpaused nonReentrant {
        require(totalMinted[msg.sender] + 1 <= 10);
        if (totalSupply() >= MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        if (msg.value < MINT_PRICE) {
            revert InsufficientBalance();
        }
        uint256 supply = totalSupply();
        _safeMint(to, supply + 1);
        totalMinted[msg.sender] += 1;
        emit Minted(to, supply + 1);
    }

    function batchMintNFT(address to, uint256 amount)
        external
        payable
        onlyUnpaused
        nonReentrant
    {
        require(amount > 0, "Amount must be greater than 0");
        require(totalMinted[msg.sender] + amount <= 10);
        if (totalSupply() >= MAX_SUPPLY) {
            revert MaxSupplyReached();
        }
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        if (msg.value < amount * MINT_PRICE) {
            revert InsufficientBalance();
        }
        uint256 supply = totalSupply();
        for (uint256 i = 1; i <= amount; i++) {
            _safeMint(to, supply + i);
            totalMinted[msg.sender] += 1;
            emit Minted(to, supply + i);
        }
    }

      function batchMintNFTOwner(address to, uint256 amount)
        external
        payable
        nonReentrant
    {
        require(amount > 0, "Amount must be greater than 0");
        
        if (totalSupply() >= MAX_SUPPLY) {
            revert MaxSupplyReached();
        }
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

       
        uint256 supply = totalSupply();
        for (uint256 i = 1; i <= amount; i++) {
            _safeMint(to, supply + i);
            totalMinted[msg.sender] += 1;
            emit Minted(to, supply + i);
        }
    }
   
    function seeMinted(address user) external view returns(uint256){
        return totalMinted[user];
    }


    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (ownerOf(tokenId) == address(0)) {
            revert TokenNotFound();
        }

        string memory currentBaseURI = baseUri;
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }

    function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "No balance to withdraw");

    (bool sent, ) = payable(owner()).call{value: balance}("");
    if (!sent) {
        revert WithdrawFailed();
    }

    emit Withdrawn(owner(), balance);
}
    function withdrawAmount(uint256 _amount) public onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "No balance to withdraw");

    (bool sent, ) = payable(owner()).call{value: _amount}("");
    if (!sent) {
        revert WithdrawFailed();
    }

    emit Withdrawn(owner(), balance);
}


    receive() external payable {}

    fallback() external payable {}
}
