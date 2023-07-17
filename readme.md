# Orange Lounge Radio transcription archive
This repository collects transcription files generated for the [Orange Lounge Radio](http://orangeloungeradio.com/) (part of [VOG Network](http://www.vognetwork.com/)).

# Episode sources
* Current episodes are available via [RSS feed](https://podcasts.apple.com/podcast/id73330030) or directly from [VOG Network](http://www.vognetwork.com/orange-lounge-radio/)
* Older episodes are availabe at [OLRchive](https://1drv.ms/f/s!AruI8iDXabVJ5GLBSbU1NUnzqPXL?e=sQWncC) (this repo source), original [OLRChive](https://bit.ly/OLRChive), or at [OLR Archive](https://olarchive.samurailink3.com/) by Tom Webster

# Technical details
Transcriptions were done with [OpenAI Whisper](https://github.com/openai/whisper) project using the Large EN model (there were several updates, so quality and accuracy varies).

See [Transcribe-Episodes.ps1](./Transcribe-Episodes.ps1) for comments on how to set up and run the script. Preferably you should use CUDA-accelerated Tensor Flow libraries from NVidia.

There's some rudimentary support for [WhisperX](https://github.com/m-bain/whisperX) if you can only run on CPU, but it was never extensively tested.