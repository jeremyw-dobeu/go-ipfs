package conn

import (
	"errors"
	"fmt"

	handshake "github.com/jbenet/go-ipfs/net/handshake"
	hspb "github.com/jbenet/go-ipfs/net/handshake/pb"
	u "github.com/jbenet/go-ipfs/util"

	context "github.com/jbenet/go-ipfs/Godeps/_workspace/src/code.google.com/p/go.net/context"
	proto "github.com/jbenet/go-ipfs/Godeps/_workspace/src/code.google.com/p/goprotobuf/proto"
	ma "github.com/jbenet/go-multiaddr"
)

// Handshake1 exchanges local and remote versions and compares them
// closes remote and returns an error in case of major difference
func Handshake1(ctx context.Context, c Conn) error {
	rpeer := c.RemotePeer()
	lpeer := c.LocalPeer()

	var remoteH, localH *hspb.Handshake1
	localH = handshake.Handshake1Msg()

	myVerBytes, err := proto.Marshal(localH)
	if err != nil {
		return err
	}

	c.Out() <- myVerBytes
	log.Debugf("Sent my version (%s) to %s", localH, rpeer)

	select {
	case <-ctx.Done():
		return ctx.Err()

	case <-c.Closing():
		return errors.New("remote closed connection during version exchange")

	case data, ok := <-c.In():
		if !ok {
			return fmt.Errorf("error retrieving from conn: %v", rpeer)
		}

		remoteH = new(hspb.Handshake1)
		err = proto.Unmarshal(data, remoteH)
		if err != nil {
			return fmt.Errorf("could not decode remote version: %q", err)
		}

		log.Debugf("Received remote version (%s) from %s", remoteH, rpeer)
	}

	if err := handshake.Handshake1Compatible(localH, remoteH); err != nil {
		log.Infof("%s (%s) incompatible version with %s (%s)", lpeer, localH, rpeer, remoteH)
		return err
	}

	log.Debugf("%s version handshake compatible %s", lpeer, rpeer)
	return nil
}

// Handshake3 exchanges local and remote service information
func Handshake3(ctx context.Context, c Conn) error {
	rpeer := c.RemotePeer()
	lpeer := c.LocalPeer()

	var remoteH, localH *hspb.Handshake3
	localH = handshake.Handshake3Msg(lpeer)

	rma := c.RemoteMultiaddr()
	localH.ObservedAddr = proto.String(rma.String())

	localB, err := proto.Marshal(localH)
	if err != nil {
		return err
	}

	c.Out() <- localB
	log.Debugf("Handshake1: sent to %s", rpeer)

	select {
	case <-ctx.Done():
		return ctx.Err()

	case <-c.Closing():
		return errors.New("Handshake3: error remote connection closed")

	case remoteB, ok := <-c.In():
		if !ok {
			return fmt.Errorf("Handshake3 error receiving from conn: %v", rpeer)
		}

		remoteH = new(hspb.Handshake3)
		err = proto.Unmarshal(remoteB, remoteH)
		if err != nil {
			return fmt.Errorf("Handshake3 could not decode remote msg: %q", err)
		}

		log.Debugf("Handshake3 received from %s", rpeer)
	}

	if err := handshake.Handshake3UpdatePeer(rpeer, remoteH); err != nil {
		log.Errorf("Handshake3 failed to update %s", rpeer)
		return err
	}

	return nil
}

func CheckNAT(obsaddr string) (bool, error) {
	oma, err := ma.NewMultiaddr(obsaddr)
	if err != nil {
		return false, err
	}
	addrs, err := u.GetLocalAddresses()
	if err != nil {
		return false, err
	}
	_ = oma
	_ = addrs

	panic("not yet implemented!")
}
