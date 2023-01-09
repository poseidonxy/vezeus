# Deployment steps for vezeus

#1 Deploy the Handler contract

#2 Deploy the Membership contract

#3 Deploy the Vote contract

#4 Deploy the VeZeusData contract

#5 Deploy the VeZeus contract (constructor requires the Handler contract address and the VeZeusData contract address)

#6 Deploy the Middleware contract (constructor requires the contract addresse of handler, membership, vote and vezeus)

# Setup steps for vezeus

#1 Copy the contract address of the middleware contract deployed and update the different contracts. Below are the functions that enable you setup the middleware on each contract.

    - Handler Contract: "function setAuthorities()". 

        The messenger address should be the middleware contract address. The caller address is the address which is responsible for the cronjob.

    - Membership contract: function setAuthorities()

    - veZeus contract: function setMiddlewareAddress()
    
    - vote contract: function setAuthorities()

#2 Copy the address of vZeus contract, locate the "updateVeZeusContractAddress" function in veZeusData and update it

# Notes

#1 Ensure the collector and vzeusCollector addresses are set. the vZeusCollector address is where the veZeus tokens used during vote is sent.

#2 Users need to approve the middleware contract to spend usdc, vzeus and zeus tokens on their behalf.
For the usdc - this can be triggered each time they wish to lock funds, thereby allowing only the exact amount they wish to lock at that particular point in time.

#3 For security purposes - users can only lock funds every 3 minutes

