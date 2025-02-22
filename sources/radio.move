module radio_addrx::OnChainRadio {
    use std::string::{String,utf8};
    use std::simple_map::{SimpleMap,Self};
    use aptos_framework::timestamp;
    use std::signer; 
    // use std::from_bcs;
    // use std::aptos_hash; 
    use std::account;
    use std::error;
    // use std::vector;
    // use 0x1::coin;
    // use 0x1::aptos_coin::AptosCoin; 
    // use 0x1::aptos_account;
    use aptos_framework::event;
    use aptos_framework::aptos_account;
    // use std::debug::print;
    // use aptos_framework::token;

    // define errors
    const Account_Not_Found:u64 =404;
    const Collection_Not_Found:u64=808;
    const E_NOT_ENOUGH_COINS:u64 = 202;
    const Artist_Not_Found:u64=101;


    struct Artist_work has key ,store{
        artist_name: String,
        Nonce:u64,
        Collections:SimpleMap<String,Collection>,
        Monitize_collections:SimpleMap<String,Monitize_collection>,
        Signature_Details:SimpleMap<String,SignatureDetails>,
        artist_resource_event: event::EventHandle<Collection>,

    }
    struct Collection has copy, drop,key,store {
        collectionType : String,
        collectionName : String,
        artist_address : address,
        artist_Authentication_key : vector<u8>,
        current_timestamp : u64,
        streaming_timestamp : u64,
        collection_ipfs_hash : String,
    }
    

    // call only one time
    // creates the artist_work resource 
    public entry fun create_artist_work(account : &signer, name : String)  {
        let artist_work = Artist_work {
            artist_name : name,
            Nonce:1,
            Collections : simple_map::create(),
            Monitize_collections:simple_map::create(),
            Signature_Details:simple_map::create(),
            artist_resource_event:account::new_event_handle<Collection>(account),
        };
        // debug::print(&artist_work);
        move_to(account, artist_work);
    }
    // creates collection and stores it in artist_work resource

    public entry fun create_collection (account : &signer,artist_name:String,collection_type: String,collection_name : String, streaming_timestamp: u64, ipfs_hash: String)acquires Artist_work {
        let signer_address = signer::address_of(account);
        if (!exists<Artist_work>(signer_address)){
            create_artist_work(account,artist_name);
        };
        let artist_work = borrow_global_mut<Artist_work>(signer_address);
        let signer_authentication_key=account::get_authentication_key(signer_address);
        let newCollection = Collection {
            collectionType : collection_type,
            collectionName : collection_name,
            artist_address : signer_address,
            artist_Authentication_key : signer_authentication_key,
            current_timestamp : timestamp::now_seconds(),
            streaming_timestamp : streaming_timestamp,
            collection_ipfs_hash : ipfs_hash,

        };
        let songHashId=ipfs_hash;
        simple_map::add(&mut artist_work.Collections,songHashId , newCollection);

        //update nonce for artist account
        artist_work.Nonce=artist_work.Nonce+1;

        // event
        event::emit_event<Collection>(
            &mut borrow_global_mut<Artist_work>(signer_address).artist_resource_event,
            newCollection,
        );

    }
     #[view]
    // get nonce of account
    public fun GetNonce(account:&signer) :u64 acquires Artist_work{
        let signer_address = signer::address_of(account);
        let artist_work = borrow_global<Artist_work>(signer_address);
        return artist_work.Nonce
    }
    
     #[view]
    // get collection info by songHashId
    public fun getCollectionInfo(account:&signer,_songHashId:String):SimpleMap<String,Collection> acquires Artist_work{
        let signer_address = signer::address_of(account);
        let artist_work = borrow_global<Artist_work>(signer_address);
        artist_work.Collections

    }

     #[view]
    // get monitize info by songHashId
    public fun getMonitizeInfo(account:&signer,_songHashId:String):SimpleMap<String,Monitize_collection>  acquires Artist_work{
        let signer_address = signer::address_of(account);
        let artist_work = borrow_global<Artist_work>(signer_address);
        artist_work.Monitize_collections

    }

     #[view]
     // get Signature  info by songHashId
    public fun getSignatureInfo(account:&signer,_songHashId:String):SimpleMap<String,SignatureDetails>  acquires Artist_work{
        let signer_address = signer::address_of(account);
        let artist_work = borrow_global<Artist_work>(signer_address);
        artist_work.Signature_Details

    }


    struct Monitize_collection has key,copy,drop,store{
        IsEKycVerified:bool,
        NoOfMaxCopies:u64,
        NoOfCopyReleased:u64,
        PriceOfCopy:u64,
        CertificateActivated:bool,
        Royality:u64,   // royality in %
        Ceritificate_IPFS_Address:String,
        CopyExpiryTimestamp:u64,
    }

    struct SignatureDetails has key,store,drop,copy{
        Ceritificate_Hash:vector<u8>,
        Certifiate_Signature:vector<u8>,
    }

    public entry fun Broadcast(account:&signer,songHashId:String,maxcopies:u64,currentCopies:u64,price:u64,royalities:u64,certificateAddr:String,ceritifiateHash:vector<u8>,signature:vector<u8>)acquires Artist_work{
        let monitizeDetails=Monitize_collection{
        IsEKycVerified:true,
        NoOfMaxCopies:maxcopies,
        NoOfCopyReleased:currentCopies,
        PriceOfCopy:price,
        CertificateActivated:true,
        Royality:royalities,   // royality in %
        Ceritificate_IPFS_Address:certificateAddr,
        CopyExpiryTimestamp:18446744073709551615,
        };
        let signatureDetails=SignatureDetails{
        Ceritificate_Hash:ceritifiateHash,
        Certifiate_Signature:signature,
        };
        Monitize_work(account,songHashId,monitizeDetails,signatureDetails);
    }

public fun Monitize_work(account:&signer,songHashId:String, monitize:Monitize_collection,signatuedetails:SignatureDetails) acquires Artist_work{        // check account with given hashId
        let signer_address = signer::address_of(account);
        // check account exist or not
        if (!exists<Artist_work>(signer_address)){
            error::not_found(Account_Not_Found);
        };

        let artist_work = borrow_global_mut<Artist_work>(signer_address);
        // check wheather collections exist or not for given songHashId
        if (!simple_map::contains_key(&mut artist_work.Collections,&songHashId)){
            error::not_found(Collection_Not_Found);
        };

        // push/update monitize info in artist resources
        simple_map::add(&mut artist_work.Monitize_collections,songHashId , monitize);

        // push signature and hash in resource
        simple_map::add(&mut artist_work.Signature_Details,songHashId , signatuedetails);

    }

    struct ContentInfo has copy,drop,store{
        Artist_address:address,
        Artist_signature:vector<u8>,
        CopyNumber:u64,
        Content_IPFS_address:String,
        Ceritificate_By_artist_IPFS_Address:String,
        Ceritificate_By_client_IPFS_Address:String,
        Timestamp:u64,
        Client_address:address,
        Client_signature:vector<u8>,
        Price:u64,
        Platform_name:String,
    }

    struct Client_resource has key,store{
        Collections:SimpleMap<String,ContentInfo>
        }
    
     // call only one time
    // creates the client resource 
    public entry fun create_client_resource(account : &signer)  {
        let client_resource = Client_resource {
            Collections:simple_map::create(),
        };

        move_to(account, client_resource);
    }


    // purchase copy of song after streaming

    public entry fun Purchase(account:&signer,songhashid:String,artist_address:address,signature:vector<u8>,certificateIpfsAddress:String) acquires Artist_work,Client_resource{
        let signer_address = signer::address_of(account);
         if (!exists<Client_resource>(signer_address)){
            create_client_resource(account);
        };
       let artist_work = borrow_global_mut<Artist_work>(artist_address);
        let monitizeDetails=simple_map::borrow(&mut artist_work.Monitize_collections,&songhashid);
        let signatureDetails=simple_map::borrow(&mut artist_work.Signature_Details,&songhashid);

        let contentinfo=ContentInfo{
        Artist_address:artist_address,
        Artist_signature:signatureDetails.Certifiate_Signature,
        CopyNumber:0,
        Content_IPFS_address:songhashid,
        Ceritificate_By_artist_IPFS_Address:monitizeDetails.Ceritificate_IPFS_Address,
        Ceritificate_By_client_IPFS_Address:certificateIpfsAddress,
        Timestamp:timestamp::now_seconds(),
        Client_address:signer_address,
        Client_signature:signature,
        Price:monitizeDetails.PriceOfCopy,
        Platform_name:utf8(b"ON CHAIN RADIO PLATFORM"),
    };
    aptos_account::transfer(account,artist_address,monitizeDetails.PriceOfCopy);
    let client_resource = borrow_global_mut<Client_resource>(signer_address);
    simple_map::add(&mut client_resource.Collections,songhashid , contentinfo);
    }


    //////////////////test case///////////////

       #[test(artist = @0x123,user1=@0x456,user2=@678)]
    public entry fun test_flow(artist: signer,user1:signer,user2:signer)  acquires Artist_work
    {
        account::create_account_for_test(signer::address_of(&artist));
        account::create_account_for_test(signer::address_of(&user1));
        account::create_account_for_test(signer::address_of(&user2));

        // create_artist_work(&artist,utf8(b"Welcome to Aptos anand by Example"));
        let name:String = utf8(b"arjit singh");
        let _collection_type:String = utf8(b"arjit singh");
        let _collection_name:String = utf8(b"arjit singh");
        let ipfs_hash:String = utf8(b"0x000138459257759252");
        let _certififcateaddr:String = utf8(b"0x000138459257759252");
        let streaming_timestamp: u64=timestamp::now_seconds();
        create_collection(&artist,name,_collection_type,_collection_name,streaming_timestamp,ipfs_hash);
        let _data: vector<u8> = b"example data";
        // Broadcast(&artist,ipfs_hash,1000,20,50,10,certififcateaddr,data,data);
        let _artistaddr=signer::address_of(&artist);
        ipfs_hash = utf8(b"0x0001398459257759252");
        // Purchase(&user1,ipfs_hash,artistaddr,data,certififcateaddr);
        print(&ipfs_hash);

    }

}

