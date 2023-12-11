# Debcraft: Easiest way to modify and build Debian packages

Debcraft is a tool for developers to make high quality Debian packages effortlessly.

The core design principles are:
1. Be opinionated, make the correct thing automatically without asking user to make too many decisions, and when full automation is not possible, steer users to follow the beat practices in software development.
2. Use git, git-buildpackage and quilt as Debian is on a path to standardize on them as shown by trends.debian.net.
3. Unlike traditional chroot based tools, Debcraft uses Linux containers for improved isolation, security and reproducibility.
4. Create build environment containers on the fly so users don't need to plan ahead what chroots or containers they have.
5. Have extremely fast rebuilds as that is what users are likely to spend most of their time on.
6. Store logs and artifacts from builds and help users review changes between builds and package versions to maximize users' understanding of how their changes affect the outcome.
7. Don't expect users to run the latest version of Debian or even Debian or Ubuntu at all. The barrier to run Debcraft should be as low as possible, so that anyone can participate in debugging Debian package builds and improving them.
8. Encourage users to submit improvements on Salsa and to collaborate with Debian and upstreams instead of just making their own private Debian packages.
9. Teach users about the Debian policy gradually and in context, so that over time users grow towards Debian maintainership.


## Installation

For the time being Debcraft is not available in the Debian repositories or even as a package at all. To use it, simply clone the git repository and link the script from any directory you have in your `$PATH`, such as `$HOME/bin`

```
git clone
cd debcraft
ln -s ${PWD}/debcraft.sh ~/bin/debcraft
```

## Use examples

## Documentation

See `debcraft --help` for detailed usage instructions.

## Additional information

### Development

*This project is open source and contributions are welcome!*


### Programming language: Bash

Bash was specifically chosen as the main language to keep the code contribution barrier for this tool as low as possible. Additionally, as Debcraft mainly builds upon invoking other programs via their command-line interface, using Bash scripting helps keep the code base small and lean compared to using a proper programming language to run tens of subshells. If the limitations of Bash (e.g. lack of proper testing framework) starts to feel limiting parts of this tool might be rewritten in fast to develop language like Python, Mojo, Nim, Zig or Rust.

### Name

Why the name Debcraft? Because the name debuild was already taken. The 'craft' also helps setting users in the corrymindset, hinting towards that producing high quality Debian packages and maintaining operating system over many years and decades is not just a pure technical task, but involves following industry wisdoms, anticipating unknowns and hand-crafting and tuning things to be as perfect as possible.
