# Change Log

## [v0.9.0](https://github.com/dwbutler/groupify/tree/v0.9.0) (2017-05-09)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.8.0...v0.9.0)

**Merged pull requests:**

- Switch .uniq to .distinct while dropping rails 3.2 Support [\#53](https://github.com/dwbutler/groupify/pull/53) ([rposborne](https://github.com/rposborne))
- Add timestamps to groups table in migration generator template [\#51](https://github.com/dwbutler/groupify/pull/51) ([juhazi](https://github.com/juhazi))

## [v0.8.0](https://github.com/dwbutler/groupify/tree/v0.8.0) (2016-06-11)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.7.2...v0.8.0)

**Fixed bugs:**

- Setting a group as a group member breaks has\_members associations on that group [\#45](https://github.com/dwbutler/groupify/issues/45)
- Error on add user a team on Rails 5 Beta [\#39](https://github.com/dwbutler/groupify/issues/39)
- Split group memberships [\#46](https://github.com/dwbutler/groupify/pull/46) ([juhazi](https://github.com/juhazi))

## [v0.7.2](https://github.com/dwbutler/groupify/tree/v0.7.2) (2016-05-21)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.7.1...v0.7.2)

**Merged pull requests:**

-  Some fixes to prep for rails5 [\#44](https://github.com/dwbutler/groupify/pull/44) ([wadestuart](https://github.com/wadestuart))

## [v0.7.1](https://github.com/dwbutler/groupify/tree/v0.7.1) (2015-11-19)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.7.0...v0.7.1)

**Fixed bugs:**

- Save using member resource id [\#33](https://github.com/dwbutler/groupify/issues/33)

**Merged pull requests:**

- Fixes the `member\_ids=` auto generated method on groups [\#34](https://github.com/dwbutler/groupify/pull/34) ([dwbutler](https://github.com/dwbutler))

## [v0.7.0](https://github.com/dwbutler/groupify/tree/v0.7.0) (2015-09-09)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.6.3...v0.7.0)

**Implemented enhancements:**

- Options for acts\_as\_group like class name for group\_membership [\#19](https://github.com/dwbutler/groupify/issues/19)
- Migration Generator [\#1](https://github.com/dwbutler/groupify/issues/1)
- Make group and group membership class names configurable [\#32](https://github.com/dwbutler/groupify/pull/32) ([dwbutler](https://github.com/dwbutler))

## [v0.6.3](https://github.com/dwbutler/groupify/tree/v0.6.3) (2015-08-24)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.6.2...v0.6.3)

**Fixed bugs:**

- ActiveRecord Statement Invalid for Group queries [\#30](https://github.com/dwbutler/groupify/issues/30)

**Merged pull requests:**

- Test against mysql and postgresql [\#31](https://github.com/dwbutler/groupify/pull/31) ([dwbutler](https://github.com/dwbutler))

## [v0.6.2](https://github.com/dwbutler/groupify/tree/v0.6.2) (2015-05-28)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.6.1...v0.6.2)

**Closed issues:**

- can't complete migration [\#27](https://github.com/dwbutler/groupify/issues/27)
- NameError: uninitialized constant User::GroupMembership [\#25](https://github.com/dwbutler/groupify/issues/25)

**Merged pull requests:**

- fix association name in mongoid adapter [\#29](https://github.com/dwbutler/groupify/pull/29) ([samuelebistoletti](https://github.com/samuelebistoletti))

## [v0.6.1](https://github.com/dwbutler/groupify/tree/v0.6.1) (2015-01-16)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.6.0...v0.6.1)

**Closed issues:**

- Groupify support unique groups scoped to user? [\#18](https://github.com/dwbutler/groupify/issues/18)
- Double Membership [\#14](https://github.com/dwbutler/groupify/issues/14)
- Getting uninitialized constant Assignment [\#8](https://github.com/dwbutler/groupify/issues/8)

**Merged pull requests:**

- Fixed bug that occurs when using namespaced Models [\#24](https://github.com/dwbutler/groupify/pull/24) ([byronduenas](https://github.com/byronduenas))

## [v0.6.0](https://github.com/dwbutler/groupify/tree/v0.6.0) (2014-08-27)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.6.0.rc2...v0.6.0)

## [v0.6.0.rc2](https://github.com/dwbutler/groupify/tree/v0.6.0.rc2) (2014-08-21)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.6.0.rc1...v0.6.0.rc2)

**Closed issues:**

- NoMethodError: undefined method `groups' for {:as=\>"manager"}:Hash [\#12](https://github.com/dwbutler/groupify/issues/12)
- Count functions [\#10](https://github.com/dwbutler/groupify/issues/10)
- Named Groups to be a Group [\#7](https://github.com/dwbutler/groupify/issues/7)

**Merged pull requests:**

- Active Record adapter typo fix [\#13](https://github.com/dwbutler/groupify/pull/13) ([fourfour](https://github.com/fourfour))

## [v0.6.0.rc1](https://github.com/dwbutler/groupify/tree/v0.6.0.rc1) (2014-06-18)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.5.1...v0.6.0.rc1)

**Closed issues:**

- Change the name of the group\_membership [\#9](https://github.com/dwbutler/groupify/issues/9)
- Extend to deal with group managers/leaders? [\#3](https://github.com/dwbutler/groupify/issues/3)

**Merged pull requests:**

- Membership types [\#6](https://github.com/dwbutler/groupify/pull/6) ([dwbutler](https://github.com/dwbutler))

## [v0.5.1](https://github.com/dwbutler/groupify/tree/v0.5.1) (2014-03-28)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.5.0...v0.5.1)

**Merged pull requests:**

- Allow model instances to access other models with names matching Groupify modules [\#5](https://github.com/dwbutler/groupify/pull/5) ([reed](https://github.com/reed))

## [v0.5.0](https://github.com/dwbutler/groupify/tree/v0.5.0) (2014-03-24)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.4.2...v0.5.0)

**Closed issues:**

- New Group \(Unsaved\) has members somehow [\#2](https://github.com/dwbutler/groupify/issues/2)

## [v0.4.2](https://github.com/dwbutler/groupify/tree/v0.4.2) (2013-07-02)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.4.1...v0.4.2)

## [v0.4.1](https://github.com/dwbutler/groupify/tree/v0.4.1) (2013-07-02)
[Full Changelog](https://github.com/dwbutler/groupify/compare/v0.4.0...v0.4.1)

## [v0.4.0](https://github.com/dwbutler/groupify/tree/v0.4.0) (2013-07-01)


\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*