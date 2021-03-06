%%%-------------------------------------------------------------------
%% @doc
%% == Blockchain State Channel Packet ==
%% @end
%%%-------------------------------------------------------------------
-module(blockchain_state_channel_packet_v1).

-export([
    new/3,
    packet/1, hotspot/1, region/1, signature/1,
    sign/2, validate/1,
    encode/1, decode/1
]).

-include("blockchain.hrl").
-include_lib("helium_proto/include/blockchain_state_channel_v1_pb.hrl").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-type packet() :: #blockchain_state_channel_packet_v1_pb{}.
-export_type([packet/0]).

-spec new(blockchain_helium_packet_v1:packet(), libp2p_crypto:pubkey_bin(), atom()) -> packet().
new(Packet, Hotspot, Region) ->
    #blockchain_state_channel_packet_v1_pb{
        packet=Packet,
        hotspot=Hotspot,
        region=Region
    }.

-spec packet(packet()) -> blockchain_helium_packet_v1:packet().
packet(#blockchain_state_channel_packet_v1_pb{packet=Packet}) ->
    Packet.

-spec hotspot(packet()) -> libp2p_crypto:pubkey_bin().
hotspot(#blockchain_state_channel_packet_v1_pb{hotspot=Hotspot}) ->
    Hotspot.

-spec region(packet()) -> atom().
region(#blockchain_state_channel_packet_v1_pb{region=Region}) ->
    Region.

-spec signature(packet()) -> binary().
signature(#blockchain_state_channel_packet_v1_pb{signature=Signature}) ->
    Signature.

-spec sign(packet(), function()) -> packet().
sign(Packet, SigFun) ->
    EncodedReq = ?MODULE:encode(Packet#blockchain_state_channel_packet_v1_pb{signature= <<>>}),
    Signature = SigFun(EncodedReq),
    Packet#blockchain_state_channel_packet_v1_pb{signature=Signature}.

-spec validate(packet()) -> true | {error, any()}.
validate(Packet) ->
    BasePacket = Packet#blockchain_state_channel_packet_v1_pb{signature = <<>>},
    EncodedPacket = ?MODULE:encode(BasePacket),
    Signature = ?MODULE:signature(Packet),
    PubKeyBin = ?MODULE:hotspot(Packet),
    PubKey = libp2p_crypto:bin_to_pubkey(PubKeyBin),
    case libp2p_crypto:verify(EncodedPacket, Signature, PubKey) of
        false -> {error, bad_signature};
        true -> true
    end.

-spec encode(packet()) -> binary().
encode(#blockchain_state_channel_packet_v1_pb{}=Packet) ->
    blockchain_state_channel_v1_pb:encode_msg(Packet).

-spec decode(binary()) -> packet().
decode(BinaryPacket) ->
    blockchain_state_channel_v1_pb:decode_msg(BinaryPacket, blockchain_state_channel_packet_v1_pb).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

%% ------------------------------------------------------------------
%% EUNIT Tests
%% ------------------------------------------------------------------
-ifdef(TEST).

new_test() ->
    Packet = #blockchain_state_channel_packet_v1_pb{
        packet= blockchain_helium_packet_v1:new(),
        hotspot = <<"hotspot">>
    },
    ?assertEqual(Packet, new(blockchain_helium_packet_v1:new(), <<"hotspot">>, 'US915')).

hotspot_test() ->
    Packet = new(blockchain_helium_packet_v1:new(), <<"hotspot">>, 'US915'),
    ?assertEqual(<<"hotspot">>, hotspot(Packet)).

packet_test() ->
    Packet = new(blockchain_helium_packet_v1:new(), <<"hotspot">>, 'US915'),
    ?assertEqual(blockchain_helium_packet_v1:new(), packet(Packet)).

signature_test() ->
    Packet = new(blockchain_helium_packet_v1:new(), <<"hotspot">>, 'US915'),
    ?assertEqual(<<>>, signature(Packet)).

sign_test() ->
    #{secret := PrivKey} = libp2p_crypto:generate_keys(ecc_compact),
    SigFun = libp2p_crypto:mk_sig_fun(PrivKey),
    Packet = new(blockchain_helium_packet_v1:new(), <<"hotspot">>, 'US915'),
    ?assertNotEqual(<<>>, signature(sign(Packet, SigFun))).

validate_test() ->
    #{public := PubKey, secret := PrivKey} = libp2p_crypto:generate_keys(ecc_compact),
    PubKeyBin = libp2p_crypto:pubkey_to_bin(PubKey),
    SigFun = libp2p_crypto:mk_sig_fun(PrivKey),
    Packet0 = new(blockchain_helium_packet_v1:new(), PubKeyBin, 'US915'),
    Packet1 = sign(Packet0, SigFun),
    ?assertEqual(true, validate(Packet1)).

encode_decode_test() ->
    Packet = new(blockchain_helium_packet_v1:new(), <<"hotspot">>, 'US915'),
    ?assertEqual(Packet, decode(encode(Packet))).

-endif.
