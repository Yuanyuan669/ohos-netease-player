import http from '@ohos.net.http';
import { Log } from '../common/Logger';
import {
  Song, Playlist, RawTrack, RawPlaylist, RawDetail, RawArtist, RawAlbum,
  PersonalizedResponse, TopListResponse, DetailResponse,
  RawTrackId, SongDetailResponse
} from '../model/Types';

const BASE: string = 'https://music.163.com/api';
const TIMEOUT: number = 15000;

function toPlaylist(raw: RawPlaylist): Playlist {
  let cover: string = '';
  const pic: string | undefined = raw.picUrl;
  const coverImg: string | undefined = raw.coverImgUrl;
  if (pic !== undefined && pic.length > 0) {
    cover = pic;
  } else if (coverImg !== undefined && coverImg.length > 0) {
    cover = coverImg;
  }

  let trackCount: number = 0;
  const tc: number | undefined = raw.trackCount;
  const tn: number | undefined = raw.trackNumber;
  if (tc !== undefined) {
    trackCount = tc;
  } else if (tn !== undefined) {
    trackCount = tn;
  }

  let playCount: number = 0;
  const pc: number | undefined = raw.playCount;
  if (pc !== undefined) {
    playCount = pc;
  }

  let id: number = 0;
  const rawId: number | undefined = raw.id;
  if (rawId !== undefined) {
    id = rawId;
  }

  let name: string = '';
  const rawName: string | undefined = raw.name;
  if (rawName !== undefined) {
    name = rawName;
  }

  const item: Playlist = {
    id: id,
    name: name,
    cover: cover,
    trackCount: trackCount,
    playCount: playCount
  };
  return item;
}

function toSong(raw: RawTrack): Song {
  let id: number = 0;
  const rawId: number | undefined = raw.id;
  if (rawId !== undefined) {
    id = rawId;
  }

  let name: string = '';
  const rawName: string | undefined = raw.name;
  if (rawName !== undefined) {
    name = rawName;
  }

  let duration: number = 0;
  const rawDuration: number | undefined = raw.duration;
  const rawDt: number | undefined = raw.dt;
  if (rawDuration !== undefined) {
    duration = rawDuration;
  } else if (rawDt !== undefined) {
    duration = rawDt;
  }

  // 新旧接口分别用 artists/album 和 ar/al
  let artists: RawArtist[] | undefined = raw.artists;
  if (artists === undefined) {
    artists = raw.ar;
  }
  let author: string = '';
  if (artists !== undefined) {
    for (let i = 0; i < artists.length; i++) {
      const n: string | undefined = artists[i].name;
      if (n !== undefined && n.length > 0) {
        author = author.length === 0 ? n : author + '/' + n;
      }
    }
  }

  let album: RawAlbum | undefined = raw.album;
  if (album === undefined) {
    album = raw.al;
  }
  let cover: string = '';
  if (album !== undefined) {
    const pic: string | undefined = album.picUrl;
    if (pic !== undefined) {
      cover = pic;
    }
  }

  const song: Song = {
    id: id,
    name: name,
    author: author,
    cover: cover,
    duration: duration
  };
  return song;
}

export interface PlaylistDetail {
  id: number;
  name: string;
  cover: string;
  songs: Song[];
}

export class NeteaseApi {
  static streamUrl(id: number): string {
    return 'https://music.163.com/song/media/outer/url?id=' + id + '.mp3';
  }

  private static async getBody(path: string, query: string): Promise<string> {
    const req: http.HttpRequest = http.createHttp();
    try {
      const opt: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: TIMEOUT,
        readTimeout: TIMEOUT
      };
      const resp: http.HttpResponse = await req.request(BASE + path + query, opt);
      if (resp.responseCode !== 200) {
        throw new Error('http ' + resp.responseCode);
      }
      return resp.result as string;
    } finally {
      req.destroy();
    }
  }

  // playlist/detail 未登录只给前 10 首 tracks，但 trackIds 全量；
  // v3/song/detail 一次返回元数据+fee，fee=0/8 才是免登录外链可播的曲目
  private static async songsByIds(ids: number[]): Promise<Song[]> {
    const out: Song[] = [];
    if (ids.length === 0) {
      return out;
    }
    // c 参数是 URL 里的 JSON，整表一把梭会超 GET 长度上限，200 条约 5.4KB 实测安全
    for (let start = 0; start < ids.length; start += 200) {
      const chunk: number[] = ids.slice(start, start + 200);
      const parts: string[] = [];
      for (let i = 0; i < chunk.length; i++) {
        parts.push('{"id":' + chunk[i] + '}');
      }
      try {
        const body: string =
          await NeteaseApi.getBody('/v3/song/detail', '?c=' + encodeURIComponent('[' + parts.join(',') + ']'));
        const parsed: SongDetailResponse = JSON.parse(body) as SongDetailResponse;
        const songs: RawTrack[] | undefined = parsed.songs;
        if (songs === undefined) {
          Log.warn('song/detail: no songs field for chunk@' + start);
          continue;
        }
        for (let i = 0; i < songs.length; i++) {
          const fee: number | undefined = songs[i].fee;
          if (fee !== undefined && fee !== 0 && fee !== 8) {
            continue;
          }
          const song: Song = toSong(songs[i]);
          if (song.id > 0 && song.name.length > 0) {
            out.push(song);
          }
        }
      } catch (e) {
        Log.warn('song/detail chunk@' + start + ' failed: ' + (e as Error).message);
      }
    }
    Log.info('fee filter: ' + out.length + '/' + ids.length + ' playable');
    return out;
  }

  private static normalizeList(rawList: RawPlaylist[]): Playlist[] {
    const out: Playlist[] = [];
    for (let i = 0; i < rawList.length; i++) {
      const item: Playlist = toPlaylist(rawList[i]);
      if (item.id > 0 && item.name.length > 0) {
        out.push(item);
      }
    }
    return out;
  }

  static async recommend(limit: number): Promise<Playlist[]> {
    try {
      const body: string = await NeteaseApi.getBody('/personalized/playlist', '?limit=' + limit);
      const parsed: PersonalizedResponse = JSON.parse(body) as PersonalizedResponse;
      const result: RawPlaylist[] | undefined = parsed.result;
      if (result === undefined) {
        Log.warn('recommend: no result field, code=' + parsed.code);
        return [];
      }
      const list: Playlist[] = NeteaseApi.normalizeList(result);
      Log.info('recommend ok ' + list.length);
      return list;
    } catch (e) {
      Log.warn('recommend failed: ' + (e as Error).message);
      return [];
    }
  }

  static async topList(): Promise<Playlist[]> {
    try {
      const body: string = await NeteaseApi.getBody('/toplist', '');
      const parsed: TopListResponse = JSON.parse(body) as TopListResponse;
      const list: RawPlaylist[] | undefined = parsed.list;
      if (list === undefined) {
        Log.warn('toplist: no list field, code=' + parsed.code);
        return [];
      }
      const out: Playlist[] = NeteaseApi.normalizeList(list);
      Log.info('toplist ok ' + out.length);
      return out;
    } catch (e) {
      Log.warn('toplist failed: ' + (e as Error).message);
      return [];
    }
  }

  static async playlistDetail(id: number): Promise<PlaylistDetail | null> {
    try {
      const body: string = await NeteaseApi.getBody('/v3/playlist/detail', '?id=' + id + '&n=1000');
      const parsed: DetailResponse = JSON.parse(body) as DetailResponse;
      let raw: RawDetail | undefined = parsed.result;
      if (raw === undefined) {
        raw = parsed.playlist;
      }
      if (raw === undefined) {
        Log.warn('playlist/detail: neither result nor playlist, code=' + parsed.code);
        return null;
      }

      let name: string = '';
      const rawName: string | undefined = raw.name;
      if (rawName !== undefined) {
        name = rawName;
      }
      let cover: string = '';
      const coverImg: string | undefined = raw.coverImgUrl;
      const pic: string | undefined = raw.picUrl;
      if (coverImg !== undefined && coverImg.length > 0) {
        cover = coverImg;
      } else if (pic !== undefined) {
        cover = pic;
      }

      const ids: number[] = [];
      const trackIds: RawTrackId[] | undefined = raw.trackIds;
      if (trackIds !== undefined) {
        for (let i = 0; i < trackIds.length; i++) {
          const tid: number | undefined = trackIds[i].id;
          if (tid !== undefined && tid > 0) {
            ids.push(tid);
          }
        }
      }
      if (ids.length === 0) {
        const embedded: RawTrack[] | undefined = raw.tracks;
        if (embedded !== undefined) {
          for (let i = 0; i < embedded.length; i++) {
            const sid: number | undefined = embedded[i].id;
            if (sid !== undefined && sid > 0) {
              ids.push(sid);
            }
          }
        }
      }

      let songs: Song[] = await NeteaseApi.songsByIds(ids);
      if (songs.length === 0 && ids.length > 0) {
        const embedded: RawTrack[] | undefined = raw.tracks;
        if (embedded !== undefined) {
          for (let i = 0; i < embedded.length; i++) {
            const song: Song = toSong(embedded[i]);
            if (song.id > 0) {
              songs.push(song);
            }
          }
        }
      }
      Log.info('playlist/detail ' + id + ' ok, ' + songs.length + '/' + ids.length + ' tracks shown');
      const detail: PlaylistDetail = {
        id: id,
        name: name,
        cover: cover,
        songs: songs
      };
      return detail;
    } catch (e) {
      Log.warn('playlist/detail failed: ' + (e as Error).message);
      return null;
    }
  }
}
