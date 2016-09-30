// Copyright (c) 2016 Chef Software Inc. and/or applicable contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use std::collections::HashMap;
use std::fmt;
use std::iter::IntoIterator;
use std::net::SocketAddr;
use std::ops::{Deref, DerefMut};

use uuid::Uuid;
use rand::{thread_rng, Rng};

use message::swim::Member as ProtoMember;

const PINGREQ_TARGETS: usize = 5;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Health {
    Alive,
    Suspect,
    Confirmed,
}

impl fmt::Display for Health {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            &Health::Alive => write!(f, "Alive"),
            &Health::Suspect => write!(f, "Suspect"),
            &Health::Confirmed => write!(f, "Confirmed"),
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Member {
    pub proto: ProtoMember,
}

impl Member {
    pub fn new() -> Member {
        let mut proto_member = ProtoMember::new();
        proto_member.set_id(Uuid::new_v4().simple().to_string());
        proto_member.set_incarnation(0);
        Member { proto: proto_member }
    }

    pub fn socket_address(&self) -> SocketAddr {
        match self.get_address().parse() {
            Ok(addr) => addr,
            Err(e) => {
                panic!("Cannot parse member {:?} address: {}", self, e);
            }
        }
    }
}

impl Deref for Member {
    type Target = ProtoMember;

    fn deref(&self) -> &ProtoMember {
        &self.proto
    }
}

impl DerefMut for Member {
    fn deref_mut(&mut self) -> &mut ProtoMember {
        &mut self.proto
    }
}

impl Into<Member> for ProtoMember {
    fn into(self) -> Member {
        Member { proto: self }
    }
}


// This is a Uuid type turned to a string
pub type UuidSimple = String;

#[derive(Debug, Clone)]
pub struct MemberList {
    members: HashMap<UuidSimple, Member>,
    health: HashMap<UuidSimple, Health>,
}

impl MemberList {
    pub fn new() -> MemberList {
        MemberList {
            members: HashMap::new(),
            health: HashMap::new(),
        }
    }

    pub fn insert(&mut self, member: Member, health: Health) -> Option<Member> {
        self.health.insert(String::from(member.get_id()), health);
        self.members.insert(String::from(member.get_id()), member)
    }

    pub fn health_of(&self, member: &Member) -> Option<&Health> {
        self.health.get(member.get_id())
    }

    pub fn insert_health(&mut self, member: &Member, health: Health) -> Option<Health> {
        self.health.insert(String::from(member.get_id()), health)
    }

    pub fn members(&self) -> Vec<&Member> {
        self.members.values().collect()
    }

    pub fn check_list(&self) -> Vec<Member> {
        let mut members: Vec<Member> = self.members.values().map(|v| v.clone()).collect();
        let mut rng = thread_rng();
        rng.shuffle(&mut members);
        members
    }

    pub fn pingreq_targets(&self, sending_member: &Member, target_member: &Member) -> Vec<&Member> {
        let mut members = self.members();
        let mut rng = thread_rng();
        rng.shuffle(&mut members);
        members.into_iter()
            .filter(|m| {
                m.get_id() != sending_member.get_id() && m.get_id() != target_member.get_id()
            })
            .take(PINGREQ_TARGETS)
            .collect()
    }
}

impl Deref for MemberList {
    type Target = HashMap<UuidSimple, Member>;

    fn deref(&self) -> &HashMap<UuidSimple, Member> {
        &self.members
    }
}

#[cfg(test)]
mod tests {
    mod member {
        use uuid::Uuid;
        use message::swim;
        use member::Member;

        // Sets the uuid to simple, and the incarnation to zero.
        #[test]
        fn new() {
            let member = Member::new();
            assert_eq!(member.proto.get_id().len(), 32);
            assert_eq!(member.proto.get_incarnation(), 0);
        }

        // Takes a member in from a protobuf
        #[test]
        fn new_from_proto() {
            let mut proto = swim::Member::new();
            let uuid = Uuid::new_v4();
            proto.set_id(uuid.simple().to_string());
            proto.set_incarnation(0);
            let proto2 = proto.clone();
            let member: Member = proto.into();
            assert_eq!(proto2, member.proto);
        }
    }

    mod member_list {
        use member::{Member, MemberList, Health, PINGREQ_TARGETS};

        fn populated_member_list(size: u64) -> MemberList {
            let mut ml = MemberList::new();
            for _x in 0..size {
                let m = Member::new();
                ml.insert(m, Health::Alive);
            }
            ml
        }

        #[test]
        fn new() {
            let ml = MemberList::new();
            assert_eq!(ml.len(), 0);
        }

        #[test]
        fn insert() {
            let ml = populated_member_list(4);
            assert_eq!(ml.len(), 4);
        }

        #[test]
        fn check_list() {
            let ml = populated_member_list(1000);
            let list_a = ml.check_list();
            let list_b = ml.check_list();
            assert!(list_a != list_b);
        }

        #[test]
        fn health_of() {
            let ml = populated_member_list(1);
            for member in ml.members() {
                assert_eq!(ml.health_of(member), Some(&Health::Alive));
            }
        }

        #[test]
        fn pingreq_targets() {
            let ml = populated_member_list(10);
            let members = ml.members();
            let from: &Member = members.get(0).unwrap();
            let target: &Member = members.get(1).unwrap();
            assert_eq!(ml.pingreq_targets(from, target).len(), PINGREQ_TARGETS);
        }

        #[test]
        fn pingreq_targets_excludes_pinging_member() {
            let ml = populated_member_list(3);
            let members = ml.members();
            let from: &Member = members.get(0).unwrap();
            let target: &Member = members.get(1).unwrap();
            let targets = ml.pingreq_targets(from, target);
            assert_eq!(targets.iter().find(|&&x| x.get_id() == from.get_id()).is_none(),
                       true);
        }

        #[test]
        fn pingreq_targets_excludes_target_member() {
            let ml = populated_member_list(3);
            let members = ml.members();
            let from: &Member = members.get(0).unwrap();
            let target: &Member = members.get(1).unwrap();
            let targets = ml.pingreq_targets(from, target);
            assert_eq!(targets.iter().find(|&&x| x.get_id() == target.get_id()).is_none(),
                       true);
        }

        #[test]
        fn pingreq_targets_minimum_viable_pingreq_size_is_three() {
            let ml = populated_member_list(3);
            let members = ml.members();
            let from: &Member = members.get(0).unwrap();
            let target: &Member = members.get(1).unwrap();
            let targets = ml.pingreq_targets(from, target);
            assert_eq!(targets.len(), 1);
        }
    }
}
