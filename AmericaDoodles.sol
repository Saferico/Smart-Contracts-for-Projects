

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AmericaDoodles is ERC721Enumerable, Ownable{
    using Strings for uint256;
    string private unRevealedURL="ipfs:// place here /";
    bool public isRevealed=false; //private
    string public baseURI;
    string public baseExtension = ".json";
    uint256 public cost = 0.15 ether;
    uint256 public presaleCost = 0.1 ether;
    uint256 public maxSupply = 5194;
    uint256 public maxMintAmount = 10;

    bool public paused = false;
    mapping(address => bool) public whitelisted;
    uint public presale_time;

    AggregatorV3Interface internal priceFeed;

    uint[] public reward_arr= [50000,25000,10000,5000,5000,1000,1000,1000,1000,1000];






    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
    )
    ERC721(_name, _symbol) 
    {
        priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306); //Testnet sepolia

     // priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); //Mainnet

        setBaseURI(_initBaseURI);
        mint(msg.sender, 10);
        pause(true);
    }

    uint256[] public randomNumbers;

    function getLatestPrice() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price*10**10;
    }

    function getConversionRate(int dollar_amount) public view returns (int) {

        int ethprice = getLatestPrice();
        int ethAmount_inUSD = (((dollar_amount*10**18)* 1 ether)/ethprice);


    return ethAmount_inUSD;
    }


    function giveaway() public {

        uint count=0;
        require(randomNumbers.length == 0, "Random numbers have already been generated.");
        
        while (randomNumbers.length < 10) 
        {
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randomNumbers.length))) % 5194 + 1;
            
            // Make sure the random number has not already been generated
            bool isUnique = true;
            for (uint j = 0; j < randomNumbers.length; j++) 
            {
                if (randomNumbers[j] == randomNumber) 
                {
                    isUnique = false;
                    break;
                }
            }
            
            if (isUnique) 
            {
                address payable receipent = payable (ownerOf(randomNumber));

                int reward = getConversionRate(int256(reward_arr[count]));

                receipent.transfer(uint256(reward));

                randomNumbers.push(randomNumber);
                count++;

            }
        }
    }



    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }



    function mint(address _to, uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(!paused);
        require(_mintAmount > 0);
        require(_mintAmount <= maxMintAmount);
        require(supply + _mintAmount <= maxSupply);

        if (msg.sender != owner()) 
        {
            if(block.timestamp< presale_time)
            {
                if (whitelisted[msg.sender] != true)
                {     
                    require(msg.value >= cost * _mintAmount);
                } 
                else 
                {
                    if(_mintAmount==1)
                    {
                        require(msg.value >= presaleCost * _mintAmount);
                        if(balanceOf(msg.sender) + _mintAmount >=2)
                        {
                            whitelisted[msg.sender] = false;
                        }
                    }
                    else{
                        if(balanceOf(msg.sender)<2)
                        {
                            require(msg.value >= (presaleCost * (2-balanceOf(msg.sender))+((2-balanceOf(msg.sender))-_mintAmount) * cost));
                            if(balanceOf(msg.sender)+_mintAmount >=2)
                            {
                                whitelisted[msg.sender] = false;
                            }
                        }
                    }
                    
                }
            }
            else
            {
                require(msg.value >= cost * _mintAmount);
            }
            
            send_balance(msg.value);

            
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(_to, supply + i);
        }

        if(supply + _mintAmount == maxSupply)
        {
            giveaway();
        }
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    

        function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if(isRevealed==true)
        {
            require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
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
        else{
            return unRevealedURL;
        }

    }

    function reveal_collection()public onlyOwner{
        require(isRevealed!=true,"Collection is already revealed");
        isRevealed = true;
    } 

    //only owner
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setPresaleCost(uint256 _newCost) public onlyOwner {
        presaleCost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    
    function addWhitelistUsers(address[] memory _users) public onlyOwner 
    {
        uint total_users = _users.length;
        for (uint256 i = 0; i < total_users; i++) {
            require(_users[i] !=address(0), "can't add the zero address");
            whitelisted[_users[i]] = true;
        }
    }
    function removeWhitelistUsers(address[] memory _users) public onlyOwner 
    {
        uint total_users = _users.length;
        for (uint256 i = 0; i < total_users; i++) {
            whitelisted[_users[i]] = false;
        }
    }

        function AirDrop(address[] calldata _to,uint256[] calldata _id) external onlyOwner{
        require(_to.length == _id.length,"receivers and ids have different lengths");
        for(uint i=0;i<_to.length;i++)
        {
            require(_to[i] !=address(0), "can't add the zero address");
            safeTransferFrom(msg.sender,_to[i],_id[i]);
        }
    }

        function start_launch() public onlyOwner {
        paused = false;
        presale_time +=3 days;
    }

    function send_balance( uint mint_amount ) internal {

        uint amount25 = mint_amount*(25*100000000000000000000)/100000000000000000000;
        uint amount10 = mint_amount*(10*100000000000000000000)/100000000000000000000;
        uint amount5 = mint_amount*(5*100000000000000000000)/100000000000000000000;
        uint amount2 = mint_amount*(2*100000000000000000000)/100000000000000000000;



        payable(0x5F47c176778fF58f596a8ED733D38deBB3CdC10e).transfer(amount25);
        payable(0x880793819386F669D8Baf1C36894a68D4fd3c982).transfer(amount10);
        payable(0xa7D7e8Db58BA4E3c58C4b724A5E6918c59543EFa).transfer(amount5);
        payable(0xD74eD20abEb4a2a83C042Ff202a2a08ba3b2A63A).transfer(amount2);
        payable(0xF6CF83214550642f8e5891198CDa3205d420fa4E).transfer(amount2);
        payable(0x67020fcDa99b0eB81DC94bb42A4DDad30507A2d9).transfer(amount2);
        payable(0x2A313ae33bc3E5d2D1B97fCC8536642E728e3088).transfer(amount2);

    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

}