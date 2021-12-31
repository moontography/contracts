const BigNumber = require('bignumber.js')
const { expect } = require('chai')
// const moment = require('moment')

//ERC721 token vars
let OkLetsGoNFTFactory
let okLetsGoNFTContract

//default baseTokenURI value
const _baseTokenURI = 'ipfs://'

//test wallet info
let testWalletAddress

//aggregate the amount of ETH that should be forwarded to the paymentAddress
let paymentAddress
let totalPaymentsCollected

const mintPrice = '0.0542069'

describe('OKLA NFT Contract', function () {
  //before
  before(async () => {
    const [owner] = await ethers.getSigners()

    //Contract Factory
    OkLetsGoNFTFactory = await ethers.getContractFactory('OKLA')

    //deploy contract, store result in global okLetsGoNFTContract var for tests that follow
    okLetsGoNFTContract = await OkLetsGoNFTFactory.deploy(_baseTokenURI, 1)

    //assert contract was successfully deployed and has an address
    expect(okLetsGoNFTContract.address).to.have.lengthOf(42)

    totalPaymentsCollected = ethers.BigNumber.from(0)

    //create global test wallet
    const testWallet = web3.eth.accounts.create()
    testWalletAddress = testWallet.address

    // Set payment address
    paymentAddress = testWalletAddress
    await expect(
      okLetsGoNFTContract.connect(owner).setPaymentAddress(testWalletAddress)
    ).to.not.be.reverted
  })

  //Permissions
  //High-Level Permissions
  describe('Permissions', function () {
    it('Should assign the deploying wallet / initial contract owner', async function () {
      const [owner] = await ethers.getSigners()

      //Check for owner address
      let ownerAddy = await okLetsGoNFTContract.connect(owner).owner()

      //Assert owner addres is equal to ownerAddy
      expect(ownerAddy).to.be.eq(owner.address)
    })

    it('Should not assign other wallets owner', async function () {
      const [owner, signer1] = await ethers.getSigners()

      //Check for owner address
      let ownerAddy = await okLetsGoNFTContract.connect(owner).owner()

      //Assert signer1 address does not equal ownerAddy
      expect(ownerAddy).to.not.be.eq(signer1.address)
    })
  })

  //Whitelists
  //Test gas requirements to add single / multiple
  //Adding to whitelist(s) with Permissions
  //addToPresaleWhitelist
  //removeFromPresaleWhitelist
  describe('Whitelists', function () {
    it('Should allow only the owner to add an address to the presale whitelist', async function () {
      const [owner, signer1] = await ethers.getSigners()

      //Owner - should succeed
      await expect(
        okLetsGoNFTContract
          .connect(owner)
          .addToPresaleWhitelist([signer1.address])
      ).to.not.be.reverted

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract
          .connect(signer1)
          .addToPresaleWhitelist([signer1.address])
      ).to.be.revertedWith('Ownable: caller is not the owner')
    })

    it('Should allow only the owner to add multiple addresses to the presale whitelist', async function () {
      const [owner, signer1, signer2, signer3, signer4, signer5] =
        await ethers.getSigners()

      const addressesToAddToWhitelist = [
        signer1.address,
        signer2.address,
        signer3.address,
        signer4.address,
        signer5.address,
      ]

      const numAdditionalForGasTesting = 20

      //For testing gas as adding people to whitelist requires gas. There are economies of scale when doing this in batch however.
      for (let i = 0; i < numAdditionalForGasTesting; i++) {
        addressesToAddToWhitelist.push(new ethers.Wallet.createRandom().address)
      }

      //Owner - should succeed
      await expect(
        okLetsGoNFTContract
          .connect(owner)
          .addToPresaleWhitelist(addressesToAddToWhitelist)
      ).to.not.be.reverted

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract
          .connect(signer1)
          .addToPresaleWhitelist(addressesToAddToWhitelist)
      ).to.be.revertedWith('Ownable: caller is not the owner')
    })

    it('Should allow only the owner to remove an address from the presale whitelist', async function () {
      const [owner, signer1] = await ethers.getSigners()

      //Owner - should succeed
      await expect(
        okLetsGoNFTContract
          .connect(owner)
          .removeFromPresaleWhitelist([signer1.address])
      ).to.not.be.reverted

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract
          .connect(signer1)
          .removeFromPresaleWhitelist([signer1.address])
      ).to.be.revertedWith('Ownable: caller is not the owner')
    })

    it('Should successfully added an address to the presale whitelist', async function () {
      const [owner, signer1, signer2] = await ethers.getSigners()

      //We removed signer1 from the presale list in the previous test, they should not be on the list
      let signer1WhiteListed = await okLetsGoNFTContract
        .connect(owner)
        .presaleWhitelist(signer1.address)

      expect(signer1WhiteListed).to.be.false

      //Signer 2 was added and never removed, they should be on the list
      let signer2WhiteListed = await okLetsGoNFTContract
        .connect(owner)
        .presaleWhitelist(signer2.address)

      expect(signer2WhiteListed).to.be.true
    })
  })

  //Sales
  //startPreSale
  //endPreSale
  //startPublicSale
  //endPublicSale
  describe('Sales', function () {
    it('Should not allow anyone other than the owner to start/end pre/public sale', async function () {
      const [owner, signer1] = await ethers.getSigners()

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract.connect(signer1).startPreSale()
      ).to.be.revertedWith('Ownable: caller is not the owner')

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract.connect(signer1).endPreSale()
      ).to.be.revertedWith('Ownable: caller is not the owner')

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract.connect(signer1).startPublicSale()
      ).to.be.revertedWith('Ownable: caller is not the owner')

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract.connect(signer1).endPublicSale()
      ).to.be.revertedWith('Ownable: caller is not the owner')
    })

    it('Should allow owner to start/end pre sale', async function () {
      const [owner] = await ethers.getSigners()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)

      // Start pre sale
      await okLetsGoNFTContract.connect(owner).startPreSale()

      // Pre sale active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(true)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)

      // End pre sale
      await okLetsGoNFTContract.connect(owner).endPreSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)
    })

    it('Should allow owner to start/end public sale', async function () {
      const [owner] = await ethers.getSigners()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)

      // Start public sale
      await okLetsGoNFTContract.connect(owner).startPublicSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(true)

      // End public sale
      await okLetsGoNFTContract.connect(owner).endPublicSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)
    })
  })

  //Minting
  //mint
  //getMintsLeft
  describe('Minting', function () {
    it('Should allow mint of tokens before public sale, only by owner', async function () {
      const [owner, signer1] = await ethers.getSigners()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)

      //mint 1 with non owner, should revert
      await expect(
        okLetsGoNFTContract.connect(signer1).mint(1, {
          value: ethers.utils.parseEther(mintPrice),
        })
      ).to.be.revertedWith('Sale is not active')

      expect(await okLetsGoNFTContract.balanceOf(signer1.address)).to.be.eq(0)

      //mint 50 with owner, expect to not be reverted
      //owner should bypass pre/public sale, no wallet limits with 0 cost to mint
      await expect(
        okLetsGoNFTContract.connect(owner).mint(50, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.not.be.reverted

      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(50)
    })

    it('Should allow mint of private presale for those on the whitelist only', async function () {
      const [owner, signer1, signer2] = await ethers.getSigners()

      //add signer1 to the whitelist
      await okLetsGoNFTContract
        .connect(owner)
        .addToPresaleWhitelist([signer1.address])

      //remove signer2 from the whitelist
      await okLetsGoNFTContract
        .connect(owner)
        .removeFromPresaleWhitelist([signer2.address])

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Start pre sale
      await okLetsGoNFTContract.connect(owner).startPreSale()

      // Pre sale active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(true)

      // mint 1 pre sale token, with non presale address, should revert
      await expect(
        okLetsGoNFTContract.connect(signer2).mint(1, {
          value: ethers.utils.parseEther(mintPrice),
        })
      ).to.be.revertedWith('Must be on whitelist')

      //assert there is still no token in signer2's wallet
      expect(await okLetsGoNFTContract.balanceOf(signer2.address)).to.be.eq(0)

      // mint 1 pre sale token, with 0 value, should revert
      await expect(
        okLetsGoNFTContract.connect(signer1).mint(1, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.be.revertedWith('ETH amount sent is not correct')

      //assert there is still no token in signer1's wallet
      expect(await okLetsGoNFTContract.balanceOf(signer1.address)).to.be.eq(0)

      // mint 1 pre sale token
      await expect(
        okLetsGoNFTContract.connect(signer1).mint(1, {
          value: ethers.utils.parseEther(mintPrice),
        })
      ).to.not.be.reverted

      //add to total
      totalPaymentsCollected = totalPaymentsCollected.add(
        ethers.utils.parseEther(mintPrice)
      )

      //assert there is 1 token in signer1's wallet
      expect(await okLetsGoNFTContract.balanceOf(signer1.address)).to.be.eq(1)

      //expect 51 less mint left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(4949)

      //expect token id 51 to exist
      await expect(okLetsGoNFTContract.tokenURI(51)).to.not.be.reverted

      //expect token id 52 to not exist
      await expect(okLetsGoNFTContract.tokenURI(52)).to.be.revertedWith(
        'Nonexistent token'
      )
    })

    it('Should not allow minting of more than the allotted maxWalletAmount', async function () {
      const [owner, , signer2] = await ethers.getSigners()

      // Start public sale
      await okLetsGoNFTContract.connect(owner).startPublicSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(true)

      // maxWalletAmount = 10, try minting 101, should revert
      await expect(
        okLetsGoNFTContract.connect(signer2).mint(11, {
          value: ethers.utils.parseEther(
            new BigNumber(mintPrice).times(11).toFixed()
          ),
        })
      ).to.be.revertedWith(
        'Requested amount exceeds maximum mint amount per wallet'
      )

      //assert there is still no token in signer2's wallet
      expect(await okLetsGoNFTContract.balanceOf(signer2.address)).to.be.eq(0)

      // maxWalletAmount = 10, try minting 2
      await expect(
        okLetsGoNFTContract.connect(signer2).mint(2, {
          value: ethers.utils.parseEther(
            new BigNumber(mintPrice).times(2).toFixed()
          ),
        })
      ).to.not.be.reverted

      //add to total
      totalPaymentsCollected = totalPaymentsCollected.add(
        ethers.utils.parseEther(new BigNumber(mintPrice).times(2).toFixed())
      )

      //assert there is 2 tokens in signer2's wallet
      expect(await okLetsGoNFTContract.balanceOf(signer2.address)).to.be.eq(2)

      //expect 2 less mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(4947)
    })

    it('Should not allow minting of more than the max amount of mints per sale round', async function () {
      const [owner, signer1] = await ethers.getSigners()

      // Start public sale
      await okLetsGoNFTContract.connect(owner).startPublicSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(true)

      // Set max mints per sale round to 100 for testing purposes
      await okLetsGoNFTContract.connect(owner).setMaxMintsPerSaleRound(100)

      // maxMintsPerSaleRound = 100, try minting 101, should revert
      await expect(
        okLetsGoNFTContract.connect(owner).mint(101, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.be.revertedWith(
        'Minting would exceed max mint amount per sale round'
      )

      //assert there is still 50 tokens in owners wallet
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(50)

      //expect same amount of mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(4947)

      //expect same amount of mints per sale left
      expect(await okLetsGoNFTContract.getMintsLeftPerSaleRound()).to.be.eq(100)

      // Try minting 10, should not revert
      await expect(
        okLetsGoNFTContract.connect(owner).mint(10, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.not.be.reverted

      //assert there are 60 tokens in owners wallet
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(60)

      //expect 4937 mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(4937)

      //expect 90 mints left per sale round
      expect(await okLetsGoNFTContract.getMintsLeftPerSaleRound()).to.be.eq(90)

      // Try minting 90, should not revert and should end pre/public sale
      await expect(
        okLetsGoNFTContract.connect(owner).mint(90, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.not.be.reverted

      //assert there are 150 tokens in owners wallet
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(150)

      //expect 4847 mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(4847)

      //expect 0 mints left per sale round
      expect(await okLetsGoNFTContract.getMintsLeftPerSaleRound()).to.be.eq(0)

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)

      // Public sale not active, should revert
      await expect(
        okLetsGoNFTContract.connect(signer1).mint(1, {
          value: ethers.utils.parseEther(mintPrice),
        })
      ).to.be.revertedWith('Sale is not active')
    })

    it('Should not allow minting of more than the total amount of tokens', async function () {
      const [owner] = await ethers.getSigners()

      // Start public sale
      await okLetsGoNFTContract.connect(owner).startPublicSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(true)

      // TOTAL_TOKENS = 10000/2 = 5000 (per chain), 4847 mints left, try minting 4848, should revert
      await expect(
        okLetsGoNFTContract.connect(owner).mint(4848, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.be.revertedWith('Minting would exceed max supply')

      //assert there is still 150 tokens in owners wallet
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(150)

      //expect same amount of mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(4847)

      // Try minting 10, should not revert
      await expect(
        okLetsGoNFTContract.connect(owner).mint(10, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.not.be.reverted

      //assert there are 160 tokens in owners wallet
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(160)

      //expect 4837 mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(4837)
    })

    it('Should end token id on correct id when minting last token', async function () {
      const [owner] = await ethers.getSigners()

      // Start public sale
      await okLetsGoNFTContract.connect(owner).startPublicSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(true)

      // Set max mints per sale round to 5000 for testing purposes
      await okLetsGoNFTContract.connect(owner).setMaxMintsPerSaleRound(5000)
      
      // 4837 tokens left, try minting all remaining tokens
      await expect(
        okLetsGoNFTContract.connect(owner).mint(37, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.not.be.reverted
      
      // For testing, mint multiple batches.
      for (let i = 0; i < 48; i++) {
        await expect(
          okLetsGoNFTContract.connect(owner).mint(100, {
            value: ethers.utils.parseEther('0'),
          })
        ).to.not.be.reverted  
      }

      //assert there are 4997 tokens in owners wallet
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(4997)

      //expect same amount of mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(0)

      // Try minting 1, should revert
      await expect(
        okLetsGoNFTContract.connect(owner).mint(1, {
          value: ethers.utils.parseEther('0'),
        })
      ).to.be.revertedWith('Minting would exceed max supply')

      //assert there are 4997 tokens in owners wallet
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(4997)

      //expect 0 mints left
      expect(await okLetsGoNFTContract.getMintsLeft()).to.be.eq(0)

      //check token mint ids - 9998 should not exisit, 9999 should exist, 10000 should not, 10001 should not exists
      await expect(okLetsGoNFTContract.tokenURI(9998)).to.be.revertedWith(
        'Nonexistent token'
      )
      await expect(okLetsGoNFTContract.tokenURI(9999)).to.not.be.reverted
      await expect(okLetsGoNFTContract.tokenURI(10000)).to.be.revertedWith(
        'Nonexistent token'
      )
      await expect(okLetsGoNFTContract.tokenURI(10001)).to.be.revertedWith(
        'Nonexistent token'
      )
    })
  })

  //Token Management
  //_baseURI
  //setBaseURI
  //tokenURI
  //safeTransferFrom - inherited from OZ 721
  describe('Token Management', function () {
    it('Should allow public read of the baseTokenURI via _baseURI', async function () {
      let tokenURI = await okLetsGoNFTContract.tokenURI(1)

      expect(tokenURI).to.equal('ipfs://1.json')
    })

    it('Should allow owner to change the baseTokenURI via setBaseURI()', async function () {
      const [owner] = await ethers.getSigners()
      await expect(
        okLetsGoNFTContract.connect(owner).setBaseURI('ipfs://test/')
      ).to.not.be.reverted //_baseTokenURI is global test var in the header

      //check that baseTokenURI updated was successful
      let tokenURI = await okLetsGoNFTContract.tokenURI(1)

      expect(tokenURI).to.equal('ipfs://test/1.json')
    })

    it('Should allow a token owner to transfer that token to another address', async function () {
      const [owner, signer1, signer2] = await ethers.getSigners()

      //assert current token balances for signer1 and signer 2
      expect(await okLetsGoNFTContract.balanceOf(signer1.address)).to.be.eq(1)
      expect(await okLetsGoNFTContract.balanceOf(signer2.address)).to.be.eq(2)

      //safeTransfer token 101 from signer1 to signer2
      //safeTransferFrom is an overloaded function so to call it via etherjs do thus:
      await expect(
        okLetsGoNFTContract
          .connect(signer1)
          ['safeTransferFrom(address,address,uint256)'](
            signer1.address,
            signer2.address,
            101
          )
      ).to.not.be.reverted

      //assert current token balances for signer1 and signer 2
      expect(await okLetsGoNFTContract.balanceOf(signer1.address)).to.be.eq(0)
      expect(await okLetsGoNFTContract.balanceOf(signer2.address)).to.be.eq(3)
    })
  })

  // Custom Mint/Burn
  // Used for cross chain bridging 
  describe('Custom Mint/Burn', function () {
    it('Should allow only the owner to add an address to the authorized addesses', async function () {
      const [owner, signer1] = await ethers.getSigners()

      //Not Owner - should fail
      await expect(
        okLetsGoNFTContract
          .connect(signer1)
          .addToAuthorizedAddresses([signer1.address])
      ).to.be.revertedWith('Ownable: caller is not the owner')

      //Owner - should succeed
      await expect(
        okLetsGoNFTContract
          .connect(owner)
          .addToAuthorizedAddresses([signer1.address])
      ).to.not.be.reverted
    })

    it('Should allow only the owner and any authorized addresses to call custom functions', async function () {
      const [owner, signer1, signer2, signer3] = await ethers.getSigners()

      // End public sale
      await okLetsGoNFTContract.connect(owner).endPublicSale()

      // Pre sale not active
      expect(await okLetsGoNFTContract.preSaleActive()).to.equal(false)

      // Public sale not active
      expect(await okLetsGoNFTContract.publicSaleActive()).to.equal(false)

      //Not Owner or authorized - should fail
      await expect(
        okLetsGoNFTContract
          .connect(signer2)
          .customMint(2, signer3.address)
      ).to.be.revertedWith('Not authorized')

      //Owner - should succeed
      await expect(
        okLetsGoNFTContract
          .connect(owner)
          .customMint(2, signer3.address)
      ).to.not.be.reverted

      //expect token id 2 to exist
      await expect(okLetsGoNFTContract.tokenURI(2)).to.not.be.reverted
      expect(await okLetsGoNFTContract.balanceOf(signer3.address)).to.be.eq(1)

      //Authorized - should succeed
      await expect(
        okLetsGoNFTContract
          .connect(signer1)
          .customMint(4, signer3.address)
      ).to.not.be.reverted

      //expect token id 4 to exist
      await expect(okLetsGoNFTContract.tokenURI(4)).to.not.be.reverted
      expect(await okLetsGoNFTContract.balanceOf(signer3.address)).to.be.eq(2)
      
      //give authorized address approval to transfer token
      await expect(
        okLetsGoNFTContract
          .connect(signer3)
          .approve(signer1.address, 4)
      ).to.not.be.reverted

      //Authorized - should succeed
      await expect(
        okLetsGoNFTContract
          .connect(signer1)
          .customBurn(4)
      ).to.not.be.reverted
      
      //expect token id 4 to be transferred to owner
      expect(await okLetsGoNFTContract.balanceOf(owner.address)).to.be.eq(4998)
    })
  })

  //Contract Management
  //pause
  //unpause
  describe('Contract Management', function () {
    it('Should allow owner to pause transfers', async function () {
      const [owner, signer1, signer2] = await ethers.getSigners()
      await expect(okLetsGoNFTContract.connect(owner).pause()).to.not.be
        .reverted

      //assert that signer2 cannot send token 101 back to signer1 as the ERC721Pausable has been paused
      await expect(
        okLetsGoNFTContract
          .connect(signer2)
          ['safeTransferFrom(address,address,uint256)'](
            signer2.address,
            signer1.address,
            101
          )
      ).to.be.revertedWith('ERC721Pausable: token transfer while paused')
    })

    it('Should allow owner to unpause transfers', async function () {
      const [owner, signer1, signer2] = await ethers.getSigners()
      await expect(okLetsGoNFTContract.connect(owner).unpause()).to.not.be
        .reverted

      //assert that signer2 can now send token 101 back to signer1 as the ERC721Pausable has been unpaused
      await expect(
        okLetsGoNFTContract
          .connect(signer2)
          ['safeTransferFrom(address,address,uint256)'](
            signer2.address,
            signer1.address,
            101
          )
      ).to.not.be.reverted

      //assert current token balances for signer1 and signer 2
      expect(await okLetsGoNFTContract.balanceOf(signer1.address)).to.be.eq(1)
      expect(await okLetsGoNFTContract.balanceOf(signer2.address)).to.be.eq(2)
    })
  })

  //Payment
  //test ensures paymentAddress has received the ETH expected from the mint function
  describe('Payment', function () {
    it('Should send ETH from mint() to paymentAddress', async function () {
      let balance = await ethers.provider.getBalance(paymentAddress)

      expect(balance).to.be.eq(totalPaymentsCollected)
    })
  })
})
